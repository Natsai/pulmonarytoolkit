function result = TDLevelSets2D(original_image, initial_mask, bounds, figure_handle, reporting)
    % TDLevelSets2D. 2D level set algorithm based on image gradient
    %
    %
    %     Licence
    %     -------
    %     Part of the TD Pulmonary Toolkit. http://code.google.com/p/pulmonarytoolkit
    %     Author: Tom Doel, 2012.  www.tomdoel.com
    %     Distributed under the GNU GPL v3 licence. Please see website for details.
    %    
    

    result = initial_mask.BlankCopy;
    result.ImageType = TDImageType.Colormap;
    
    initial_mask.ChangeRawImage(logical(initial_mask.RawImage));
    
    options = [];
    options.num_iterations = 500;
    options.std_dev = 2;
    options.c = 0; % No speed set. Typical value of =0.5
    options.dt = 0.5;
    options.k = 2;
    options.alpha = 0.01;
    options.upper_bound = single(bounds(2)); % Typical value 330;
    options.lower_bound = single(bounds(1)); % Typical value 0;
    options.curv_multiple = 1;

    result_raw = SolveLevelSets(original_image, initial_mask, options, figure_handle, reporting);

    result.ChangeRawImage(result_raw);
end

function result = SolveLevelSets(original_image, initial_mask, options, figure_handle, reporting)
    initial_mask = initial_mask.RawImage;
    im = double(original_image.RawImage);

    figure(figure_handle);
    imagesc(im); hold on; colormap gray; colorbar; axis square;
    
    if (nargin < 2)
        initial_mask = GetInitialContourMask(im);
    end
    
    psi = initialise(initial_mask);

    force_handle = @force_combined;
    gaussian_im = gaussian_filter(im, 0, options.std_dev);
    
    im = gaussian_im;

    contour_handle = [];
    
    hold off;
    imagesc(im);
    hold on;
    
    for iter = 1 : options.num_iterations
        
        psi = NextContour(psi, im, gaussian_im, options, force_handle);
        if (mod(iter, 10) == 0)
            psi = re_initialise(psi);
        end
        
        if (mod(iter, 20) == 0)
            if ~isempty(contour_handle)
                delete(contour_handle);
            end
            [~, contour_handle] = contour(psi,[0 0], 'r');
            title(['Iteration ' num2str(iter)]);
            drawnow;
        end
    end
    
    result = (psi > 0);
end

function UpdateOverlayImage(phi, template, reporting)
    mask_ini = (phi>0);
    template.ChangeRawImage(mask_ini);
    reporting.UpdateOverlaySubImage(template);
    drawnow;
end

function next_psi = NextContour(psi, im, gaussian_im, options, force_function)
    [gX, gY] = gradient(psi);
    modgrad = sqrt(gX.^2 + gY.^2);
    next_psi = psi - force_function(psi, im, gaussian_im, options).*modgrad*options.dt;
end

function F = force_curvature(psi, im, gaussian_im, options)
    F = options.c + options.curv_multiple*curvature(psi);
end

function F = force_gradient(psi, im, gaussian_im, options)
    [gX, gY] = gradient(gaussian_im);
    modgrad = sqrt(gX.^2 + gY.^2);
    
    force_curv = force_curvature(psi, im, gaussian_im, options);
    g = options.k./(options.k + modgrad);
    F = force_curv.*g;
end

function F = force_region(psi, im, gaussian_im,  options)
    in_region = im < (options.lower_bound + (options.upper_bound - options.lower_bound)/2);
    F = (2*in_region - 1).*im - in_region*options.lower_bound + (1 - in_region)*options.upper_bound;
    F = -F;
end

function F = force_combined(psi, im, gaussian_im, options)
    F = options.alpha*force_region(psi, im, gaussian_im, options) + (1 - options.alpha)*force_gradient(psi, im, gaussian_im, options);
end

function F = force_basic(psi, im, gaussian_im, options)
    F = force_curvature(psi, im, gaussian_im, options);
end

function mask = GetInitialContourMask(im)
    [x,y] = getline('closed');
    mask = poly2mask(x,y,size(im,1),size(im,2));
end

function phi = initialise(mask)
    dist=-bwdist(mask) + .5;
    dist2=bwdist(1 - mask) - .5;
    dist(mask) = dist2(mask);
    
    phi = dist;
end

function curv = curvature(phi)

    gX = convn(phi, [-1 0 1]/2, 'same');
    gY = convn(phi, [-1;0;1]/2, 'same');
    gXX = convn(phi, [-1 2 -1]/4, 'same');
    gYY = convn(phi, [-1;2;-1]/4, 'same');
    gXY = convn(phi, [-1 0 1; 0 0 0; 1 0 -1]./4, 'same');

    modgrad = ( gX.^2 + gY.^2 );
    curv = ( gXX .* gY.^2 + gYY .* gX.^2 - 2 * gX .* gY .* gXY ) ./ ( modgrad .^ (3/2) + .01 ) ;
end

function phi2 = re_initialise(phi)
    phi=interpn(phi,2);
    mask_ini = (phi>0);
    dist=-bwdist(mask_ini)+.5;
    dist2=bwdist(1-mask_ini)-.5;
    dist(mask_ini)=dist2(mask_ini);
    
    [x2,y2]=ndgrid(1:4:size(phi,1), 1:4:size(phi,2));
    phi2 = interpn(dist,x2,y2);
end