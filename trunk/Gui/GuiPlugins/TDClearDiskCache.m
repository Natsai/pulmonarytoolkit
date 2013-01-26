classdef TDClearDiskCache < TDGuiPlugin
    % TDClearDiskCache. Gui Plugin for deleting all cached results files for the current dataset
    %
    %     You should not use this class within your own code. It is intended to
    %     be used by the gui of the Pulmonary Toolkit.
    %
    %     TDClearDiskCache is a Gui Plugin for the TD Pulmonary Toolkit. 
    %     The gui will create a button for the user to run this plugin.
    %     Running this plugin will delete all results files from the current 
    %     dataset results cache folder. Certain internal cache files will not be
    %     removed.
    %
    %
    %     Licence
    %     -------
    %     Part of the TD Pulmonary Toolkit. http://code.google.com/p/pulmonarytoolkit
    %     Author: Tom Doel, 2012.  www.tomdoel.com
    %     Distributed under the GNU GPL v3 licence. Please see website for details.
    %    
    
    properties
        ButtonText = 'Delete Cache'
        ToolTip = 'Clear all cached results for this dataset'
        Category = 'File'

        HidePluginInDisplay = false
        PTKVersion = '1'
        ButtonWidth = 4
        ButtonHeight = 1
    end
    
    methods (Static)
        function RunGuiPlugin(ptk_gui_app)
            % Delete files from the disk cache
            ptk_gui_app.ClearCacheForThisDataset;
            
            % Refresh the preview images
            ptk_gui_app.RefreshPlugins;
        end
    end
    
end

