function results = TDGetCentrelineFromAirways(lung_image, airway_results, reporting)
    % TDGetCentrelineFromAirways. Computes the centreline and radius for a
    % segmented airway tree.
    %
    %
    %
    %     Licence
    %     -------
    %     Part of the TD Pulmonary Toolkit. http://code.google.com/p/pulmonarytoolkit
    %     Author: Tom Doel, 2012.  www.tomdoel.com
    %     Distributed under the GNU GPL v3 licence. Please see website for details.
    %    
    
    airway_segented_image = TDGetImageFromAirwayResults(airway_results.AirwayTree, lung_image, reporting);
    
    
    reporting.ShowProgress('Finding airways');
    
    start_point_global = airway_results.StartPoint;
    start_point_index = sub2ind(airway_results.ImageSize, start_point_global(1), start_point_global(2), start_point_global(3));
    
    
    start_point_local = airway_segented_image.GlobalToLocalCoordinates(start_point_global);
    end_points = airway_results.EndPoints;
    fixed_points = [start_point_index, end_points];
    
    % No need for this line since the image from TDGetImageFromAirwayResults
    % does not include exploded points
    %             airway_segented_image.ChangeRawImage(uint8(airway_segented_image.RawImage == 1));
    
    % While each branch of the tree has been closed, there may still be
    % holes where branches meet. Hence we perform a hole filling to
    % ensure this does not cause topoligcal problems with the
    % skeletonisation
    reporting.ShowProgress('Filling holes in airway tree');
    airway_segented_image = TDFillHolesInImage(airway_segented_image);
    
    % Skeletonise
    reporting.ShowProgress('Reducing airways to a skeleton');
    skeleton_image = TDSkeletonise(airway_segented_image, fixed_points, reporting);
    
    % The final processing removes closed loops and sorts the skeleton
    % points into a tree strcuture
    reporting.ShowProgress('Processing skeleton tree');
    skeleton_results = TDProcessAirwaySkeleton(skeleton_image.RawImage, start_point_local, reporting);
    skeleton_results.airway_skeleton.RecomputeGenerations(1);
    
    % Compute radius for each branch
    reporting.ShowProgress('Computing radius for each branch');
    dt_image = airway_segented_image.RawImage;
    dt_image = dt_image == 0;
    dt_image = bwdist(dt_image);
    [radius_results, skeleton_tree] = GetRadius(lung_image, skeleton_results.airway_skeleton, dt_image, reporting);
    centreline_tree_model = TDTreeModel.CreateFromSkeletonTree(skeleton_tree, lung_image);
    
    
    results = [];
    results.AirwayCentrelineTree = centreline_tree_model;
    results.OriginalCentrelinePoints = skeleton_image.LocalToGlobalIndices(skeleton_results.original_skeleton_points);
    results.BifurcationPoints = skeleton_image.LocalToGlobalIndices(skeleton_results.bifurcation_points);
    results.CentrelinePoints = skeleton_image.LocalToGlobalIndices(skeleton_results.skeleton_points);
    results.ImageSize = lung_image.OriginalImageSize;
    results.StartPoint = start_point_global;
    results.RemovedPoints = skeleton_image.LocalToGlobalIndices(skeleton_results.removed_points);
    
end

function [results, airway_skeleton] = GetRadius(lung_image, airway_skeleton, dt_image, reporting)
    segments_to_do = airway_skeleton;
    results = {};
    
    number_of_segments = airway_skeleton.CountBranches;
    segments_done = 0;
    
    lung_image_as_double = lung_image.BlankCopy;
    lung_image_as_double.ChangeRawImage(double(lung_image.RawImage));
    
    while ~isempty(segments_to_do)
        reporting.UpdateProgressValue(round(100*segments_done/number_of_segments));
        segments_done = segments_done + 1;
        next_segment = segments_to_do(end);
        segments_to_do(end) = [];
        segments_to_do = [segments_to_do next_segment.Children];
        
        next_result = TDComputeRadiusForBranch(next_segment, lung_image_as_double, dt_image);
        results{end+1} = next_result;
        
        next_segment.Radius = next_result.Radius;
        
    end
end

