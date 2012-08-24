classdef TDImageUtilities
    % TDImageCoordinateUtilities. Utility functions related to displaying images
    %
    %
    %     Licence
    %     -------
    %     Part of the TD Pulmonary Toolkit. http://code.google.com/p/pulmonarytoolkit
    %     Author: Tom Doel, 2012.  www.tomdoel.com
    %     Distributed under the GNU GPL v3 licence. Please see website for details.
    %    
        
    methods (Static)
        
        % Returns a 2D image slice and alpha information
        function [rgb_slice alpha_slice] = GetImage(image_slice, limits, image_type, window, level)
            switch image_type
                case TDImageType.Grayscale
                    rescaled_image_slice = TDImageUtilities.RescaleImage(image_slice, window, level);
                    [rgb_slice, alpha_slice] = TDImageUtilities.GetBWImage(rescaled_image_slice);
                case TDImageType.Colormap
                    [rgb_slice, alpha_slice] = TDImageUtilities.GetLabeledImage(image_slice);
                case TDImageType.Scaled
                    [rgb_slice, alpha_slice] = TDImageUtilities.GetColourMap(image_slice, limits);
            end
            
        end
        
        % Returns an RGB image from a greyscale matrix
        function [rgb_image alpha] = GetBWImage(image)
            rgb_image = (cat(3, image, image, image));
            alpha = ones(size(image));
        end

        % Returns an RGB image from a colormap matrix
        function [rgb_image alpha] = GetLabeledImage(image)
            data_class = class(image);
            if strcmp(data_class, 'double') || strcmp(data_class, 'single')
                rgb_image = label2rgb(round(image), 'lines');
            else
                rgb_image = label2rgb(image, 'lines');
            end
            alpha = int8(image ~= 0);
        end

        % Returns an RGB image from a scaled floating point scalar image
        function [rgb_image alpha] = GetColourMap(image, image_limits)
            image_limits(1) = min(0, image_limits(1));
            image_limits(2) = max(0, image_limits(2));
            positive_mask = image >= 0;
            rgb_image = zeros([size(image), 3], 'uint8');
            positive_image = abs(double(image))/abs(double(image_limits(2)));
            negative_image = abs(double(image))/abs(double(image_limits(1)));
            rgb_image(:, :, 1) = uint8(positive_mask).*(uint8(255*positive_image));
            rgb_image(:, :, 3) = uint8(~positive_mask).*(uint8(255*negative_image));
            
            alpha = int8(min(1, abs(max(positive_image, negative_image))));
        end
        
        % Rescale image to a single-byte in the range 0-255.
        function rescaled_image = RescaleImage(image, window, level)
            min_value = double(level - window/2);
            max_value = double(level + window/2);
            scale_factor = 255/(max_value - min_value);
            rescaled_image = uint8(min(((image - min_value)*scale_factor), 255));
        end  
        
        % Draws box lines around a point in all dimensions, to emphasize that
        % point. Used by the show trachea plugin.
        function image = DrawBoxAround(image, centre_point, box_size, colour)
            if length(box_size) == 1
                box_size = [box_size, box_size, box_size];
            end
            
            image(centre_point(1)-box_size(1):centre_point(1)+box_size(1), centre_point(2)-box_size(2), centre_point(3)) = colour;
            image(centre_point(1)-box_size(1):centre_point(1)+box_size(1), centre_point(2)+box_size(2), centre_point(3)) = colour;
            image(centre_point(1)-box_size(1), centre_point(2)-box_size(2):centre_point(2)+box_size(2), centre_point(3)) = colour;
            image(centre_point(1)+box_size(1), centre_point(2)-box_size(2):centre_point(2)+box_size(2), centre_point(3)) = colour;
            
            image(centre_point(1), centre_point(2)-box_size(2), max(1, centre_point(3)-box_size(3)):centre_point(3)+box_size(3)) = colour;
            image(centre_point(1), centre_point(2)+box_size(2), max(1, centre_point(3)-box_size(3)):centre_point(3)+box_size(3)) = colour;
            image(centre_point(1), centre_point(2)-box_size(2):centre_point(2)+box_size(2), max(1, centre_point(3)-box_size(3))) = colour;
            image(centre_point(1), centre_point(2)-box_size(2):centre_point(2)+box_size(2), centre_point(3)+box_size(3)) = colour;
            
            image(centre_point(1)-box_size(1), centre_point(2), max(1, centre_point(3)-box_size(3)):centre_point(3)+box_size(3)) = colour;
            image(centre_point(1)+box_size(1), centre_point(2), max(1, centre_point(3)-box_size(3)):centre_point(3)+box_size(3)) = colour;
            image(centre_point(1)-box_size(1):centre_point(1)+box_size(1), centre_point(2), max(1, centre_point(3)-box_size(3))) = colour;
            image(centre_point(1)-box_size(1):centre_point(1)+box_size(1), centre_point(2), centre_point(3)+box_size(3)) = colour;
        end
        
        % Construct a new image of zeros or logical false, depending on the
        % image class.
        function new_image = Zeros(image_size, image_class)
            if strcmp(image_class, 'logical')
                new_image = false(image_size);
            else
                new_image = zeros(image_size, image_class);
            end
        end
        
        function ball_element = CreateBallStructuralElement(voxel_size, size_mm)
            strel_size_voxels = ceil(size_mm./(2*voxel_size));
            ispan = -strel_size_voxels(1) : strel_size_voxels(1);
            jspan = -strel_size_voxels(2) : strel_size_voxels(2);
            kspan = -strel_size_voxels(3) : strel_size_voxels(3);
            [i, j, k] = ndgrid(ispan, jspan, kspan);
            i = i.*voxel_size(1);
            j = j.*voxel_size(2);
            k = k.*voxel_size(3);
            ball_element = zeros(size(i));
            ball_element(:) = sqrt(i(:).^2 + j(:).^2 + k(:).^2);
            ball_element = ball_element <= (size_mm/2);
        end
    end
end
