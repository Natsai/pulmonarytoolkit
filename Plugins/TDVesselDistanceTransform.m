classdef TDVesselDistanceTransform < TDPlugin
    % TDVesselDistanceTransform. Plugin for distance transform to blood vessels
    %
    %     This is a plugin for the Pulmonary Toolkit. Plugins can be run using 
    %     the gui, or through the interfaces provided by the Pulmonary Toolkit.
    %     See TDPlugin.m for more information on how to run plugins.
    %
    %     Plugins should not be run directly from your code.
    %
    %
    %
    %     Licence
    %     -------
    %     Part of the TD Pulmonary Toolkit. http://code.google.com/p/pulmonarytoolkit
    %     Author: Tom Doel, 2012.  www.tomdoel.com
    %     Distributed under the GNU GPL v3 licence. Please see website for details.
    %
    
    properties
        ButtonText = 'Vessel DT'
        ToolTip = 'Thresholds vesselness and computes a distance transform'
        Category = 'Vessels'
        AllowResultsToBeCached = true
        AlwaysRunPlugin = false
        PluginType = 'ReplaceOverlay'
        HidePluginInDisplay = false
        FlattenPreviewImage = false
        TDPTKVersion = '1'
        ButtonWidth = 6
        ButtonHeight = 2
        GeneratePreview = true
    end
    
    methods (Static)
        
        function results = RunPlugin(dataset, ~)    
            lung_mask = dataset.GetResult('TDLeftAndRightLungs');
            lung_mask.ChangeRawImage(uint8(lung_mask.RawImage > 0));
            vesselness = dataset.GetResult('TDVesselness');
            results = vesselness.BlankCopy;
            
            vesselness_dt = bwdist(vesselness.RawImage > 20);

            vesselness_dt(~(lung_mask.RawImage > 0)) = 0;
            results.ChangeRawImage(vesselness_dt);
            results.ImageType = TDImageType.Scaled;
        end
        
    end
    
    methods (Static, Access = private)
        function filtered_vesselness = CalculateVesselDensity(vesselness)
            vesselness_raw = single(vesselness.RawImage);
            filter_size = 10;            
            vesselness.ChangeRawImage(vesselness_raw);
            filtered_vesselness = TDGaussianFilter(vesselness, filter_size);
        end
    end
end