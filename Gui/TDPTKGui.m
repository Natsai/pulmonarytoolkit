classdef TDPTKGui < handle
    % TDPTKGui. The user interface for the TD Pulmonary Toolkit.
    %
    %     To start the user interface, run ptk.m.
    %
    %     You do not need to modify this file. To add new functionality, create
    %     new plguins in the Plugins and GuiPlugins folders.
    % 
    %
    %     Licence
    %     -------
    %     Part of the TD Pulmonary Toolkit. http://code.google.com/p/pulmonarytoolkit
    %     Author: Tom Doel, 2012.  www.tomdoel.com
    %     Distributed under the GNU GPL v3 licence. Please see website for details.
    %
    
    properties (SetAccess = private)
        ImagePanel
        Reporting
    end
    
    properties (Access = private)
        Settings
        Dataset
        Ptk
        FigureHandle
        WaitDialogHandle
        MarkersHaveBeenLoaded = false
        PluginsPanel
        DropDownLoadMenuManager
        OldWindowScrollWheelFcn

        ProfileCheckboxHandle
        UipanelImageHandle
        UipanelPluginsHandle
        PopupmenuLoadHandle
        TextVersionHandle
        UipanelVersionHandle
        
    end
    
    methods
        function obj = TDPTKGui(splash_screen)

            % Create the splash screen if it doesn't already exist
            if nargin < 1 || isempty(splash_screen) || ~isa(splash_screen, 'TDProgressInterface')
                splash_screen = TDSplashScreen;
            end

            % Create the figure and gui components
            obj.FigureHandle = figure('Color', TDSoftwareInfo.BackgroundColour, 'Visible', 'off', 'numbertitle', 'off');
            obj.UipanelImageHandle = uipanel('Parent', obj.FigureHandle, 'Units', 'pixels', 'Position', [1 1 921 921], 'BackgroundColor', TDSoftwareInfo.BackgroundColour, 'BorderType', 'none');
            obj.UipanelPluginsHandle = uipanel('Parent', obj.FigureHandle, 'Units', 'pixels', 'Position', [889 6 668 869], 'BackgroundColor', TDSoftwareInfo.BackgroundColour, 'BorderType', 'none');
            obj.UipanelVersionHandle = uipanel('Parent', obj.FigureHandle, 'Units', 'pixels', 'Position', [10 2 392 34], 'BackgroundColor', TDSoftwareInfo.BackgroundColour, 'BorderType', 'none');
            obj.PopupmenuLoadHandle = uicontrol('Parent', obj.FigureHandle', 'Style', 'popupmenu', ...
                'Units', 'pixels', 'Position', [8 912 1560 23], 'Callback', @obj.PopupmenuLoadCallback, 'String', 'Recent datasets');
            obj.TextVersionHandle = uicontrol('Parent', obj.UipanelVersionHandle, 'Style', 'text', ...
                'Units', 'pixels', 'Position', [10 2 392 34], 'BackgroundColor', TDSoftwareInfo.BackgroundColour, ...
                'FontName', 'Helvetica Neue', 'FontSize', 20.0, 'ForegroundColor', [1.0 0.694 0.392], 'HorizontalAlignment', 'left', ...
                'FontWeight', 'bold');
            obj.ProfileCheckboxHandle = uicontrol('Parent', obj.UipanelVersionHandle, 'Style', 'checkbox', 'String', 'Enable profiler', ...
                'Units', 'pixels', 'Position', [429 -8 143 49], 'BackgroundColor', TDSoftwareInfo.BackgroundColour, 'ForegroundColor', [1 1 1], ...
                'Callback', @obj.ProfileCheckboxCallback);

            % Set custom function for application closing
            set(obj.FigureHandle, 'CloseRequestFcn', @obj.CustomCloseFunction);
                        
            % Update the profile checkbox with the current status of the Matlab
            % profilers
            obj.UpdateProfilerStatus;
                        
            % Set the application name and version number
            set(obj.TextVersionHandle, 'String', obj.GetSoftwareNameAndVersionForDisplay);

            obj.ImagePanel = TDViewerPanel(obj.UipanelImageHandle);
            obj.Reporting = TDReporting(splash_screen, obj.ImagePanel);
            obj.PluginsPanel = TDPluginsPanel(obj.UipanelPluginsHandle, obj.Reporting);
            addlistener(obj.ImagePanel, 'MarkerPanelSelected', @obj.MarkerPanelSelected);
            
            obj.OldWindowScrollWheelFcn = get(obj.FigureHandle, 'WindowScrollWheelFcn');
            set(obj.FigureHandle, 'WindowScrollWheelFcn', @obj.WindowScrollWheelFcn);
            
            % For the moment, we use the splash screen to display progress,
            % because the gui isn't yet visible so the ProgressPanel won't
            % display
            obj.Reporting.Log('New session of TDPTKGui');
            
            obj.Ptk = TDPTK(obj.Reporting);
            
            obj.Settings = TDPTKSettings.LoadSettings(obj.ImagePanel, obj.Reporting);

            if isempty(obj.Settings.ScreenPosition)
                % Initialise full-screen
                units=get(obj.FigureHandle, 'units');
                set(obj.FigureHandle, 'units', 'normalized', 'outerposition', [0 0 1 1]);
                set(obj.FigureHandle, 'units', units);
                
            else
                set(obj.FigureHandle, 'Position', obj.Settings.ScreenPosition);
            end
            
            obj.DropDownLoadMenuManager = TDDropDownLoadMenuManager(obj.Settings, obj.PopupmenuLoadHandle);

            obj.PluginsPanel.AddPlugins(@obj.RunPluginCallback, @obj.RunGuiPluginCallback, []);
            
            image_info = obj.Settings.ImageInfo;
            
            if ~isempty(image_info)
                obj.LoadImages(image_info, splash_screen);
            end

            obj.ImagePanel.ShowImage = true;
            obj.ImagePanel.ShowOverlay = true;

            % Resizing will correctly lay out the GUI
            obj.Resize;

            set(obj.FigureHandle, 'ResizeFcn', @obj.ResizeCallback);
            set(obj.FigureHandle, 'Visible', 'on');

            % Now we switch to a progress panel displayed over the gui
            obj.WaitDialogHandle = TDProgressPanel(obj.UipanelImageHandle);
            obj.Reporting.ProgressDialog = obj.WaitDialogHandle;
            
            % Wait until the GUI is visible before removing the splash screen
            splash_screen.Delete;
        end

        % Causes the GUI to load the images specified either by the UID or the
        % filenames
        function Load(obj, image_info)
            obj.LoadImages(image_info, obj.WaitDialogHandle);
        end
        
        % Causes the GUI to run the named plugin and display the result
        function RunPlugin(obj, plugin_name)
            if isempty(obj.Dataset)
                return;
            end
            
            wait_dialog = obj.WaitDialogHandle;
            
            if TDSoftwareInfo.DebugMode
                obj.RunPluginTryCatchBlock(plugin_name)
            else
                try
                    obj.RunPluginTryCatchBlock(plugin_name)
                catch exc
                    if TDSoftwareInfo.IsErrorCancel(exc.identifier)
                        obj.Reporting.ShowMessage('TDPTKGuiApp:LoadingCancelled', ['The cancel button was clicked while the plugin ' plugin_name ' was running.']);
                    else
                        msgbox(['The plugin ' plugin_name ' failed with the following error: ' exc.message], [TDSoftwareInfo.Name ': Failure in plugin ' plugin_name], 'error');
                        obj.Reporting.ShowMessage('TDPTKGui:PluginFailed', ['The plugin ' plugin_name ' failed with the following error: ' exc.message]);
                    end
                end
            end
            wait_dialog.Hide;            
        end
        
        
        % Prompts the user for file(s) to load
        function SelectFilesAndLoad(obj)
            image_info = TDChooseImagingFiles(obj.Settings.SaveImagePath);
            
            % An empty image_info means the user has cancelled
            if ~isempty(image_info)
                % Save the path in the settings so that future load dialogs 
                % will start from there
                obj.Settings.SaveImagePath = image_info.ImagePath;
                obj.SaveSettings;
                
                if (image_info.ImageFileFormat == TDImageFileFormat.Dicom) && (isempty(image_info.ImageFilenames))
                    msgbox('No valid DICOM files were found in this folder', [TDSoftwareInfo.Name ': No image files found.']);
                    obj.Reporting.ShowMessage('TDPTKGuiApp:NoilesToLoad', ['No valid DICOM files were found in folder ' image_info.ImagePath]);
                else
                    obj.LoadImages(image_info, obj.WaitDialogHandle);
                end
            end
        end
               
        function SaveBackgroundImage(obj)
            patient_name = obj.ImagePanel.BackgroundImage.Title;
            image_data = obj.ImagePanel.BackgroundImage;
            path_name = obj.Settings.SaveImagePath;
            
            path_name = TDSaveAs(image_data, patient_name, path_name, obj.Reporting);
            if ~isempty(path_name)
                obj.Settings.SaveImagePath = path_name;
                obj.SaveSettings;
            end
        end
        
        function SaveOverlayImage(obj)
            patient_name = obj.ImagePanel.BackgroundImage.Title;
            image_data = obj.ImagePanel.OverlayImage;
            path_name = obj.Settings.SaveImagePath;
            
            path_name = TDSaveAs(image_data, patient_name, path_name, obj.Reporting);
            if ~isempty(path_name)
                obj.Settings.SaveImagePath = path_name;
                obj.SaveSettings;
            end
        end
        
        function SaveMarkers(obj)
            if ~isempty(obj.Dataset)
                markers = obj.ImagePanel.MarkerPointManager.GetMarkerImage;
                obj.Dataset.SaveData(TDSoftwareInfo.MakerPointsCacheName, markers);
                obj.ImagePanel.MarkerPointManager.MarkerPointsHaveBeenSaved;
            end
        end
        
        function SaveMarkersBackup(obj)
            if ~isempty(obj.Dataset)
                markers = obj.ImagePanel.MarkerPointManager.GetMarkerImage;
                obj.Dataset.SaveData('AbandonedMarkerPoints', markers);
            end
        end
        
        function SaveMarkersManualBackup(obj)
            if ~isempty(obj.Dataset)
                markers = obj.ImagePanel.MarkerPointManager.GetMarkerImage;
                obj.Dataset.SaveData('MarkerPointsLastManualSave', markers);
            end
        end

        function RefreshPlugins(obj)
            obj.PluginsPanel.RefreshPlugins(@obj.RunPluginCallback, @obj.RunGuiPluginCallback, obj.Dataset, obj.ImagePanel.Window, obj.ImagePanel.Level)
        end
        
        function display_string = GetSoftwareNameAndVersionForDisplay(~)
            display_string = [TDSoftwareInfo.Name, ' version ' TDSoftwareInfo.Version];
        end        
        
        function dataset_cache_path = GetDatasetCachePath(obj)
            if ~isempty(obj.Dataset)
                dataset_cache_path = obj.Dataset.GetDatasetCachePath;
            else
                dataset_cache_path = TDDiskCache.GetCacheDirectory;
            end
        end
        
        function ClearCacheForThisDataset(obj)
            if ~isempty(obj.Dataset)
                obj.Dataset.ClearCacheForThisDataset(false);
            end
        end
        

        function Capture(obj)
            obj.Reporting.ProgressDialog.Hide;
            frame = obj.ImagePanel.Capture;
            path_name = obj.Settings.SaveImagePath;
            [filename, path_name, filter_index] = obj.SaveImageDialogBox(path_name);
            if ~isempty(path_name) && filter_index > 0
                obj.Settings.SaveImagePath = path_name;
                obj.SaveSettings;
            end
            switch filter_index
                case 1
                    imwrite(frame.cdata, fullfile(path_name, filename), 'tif');
                case 2
                    imwrite(frame.cdata, fullfile(path_name, filename), 'jpg', 'Quality', 70);
            end
        end
        
        function DeleteImageInfo(obj)
            obj.Settings.ImageInfo = [];

            if ~isempty(obj.Dataset)
                obj.Dataset.ClearCacheForThisDataset(false);
                image_info = obj.Dataset.GetImageInfo;
                
                old_infos = obj.Settings.PreviousImageInfos;
                if old_infos.isKey(image_info.ImageUid)
                    old_infos.remove(image_info.ImageUid);
                    obj.Settings.PreviousImageInfos = old_infos;
                end
            end
            
            obj.SaveSettings;
            obj.DropDownLoadMenuManager.UpdateQuickLoadMenu;
        end
        
    end
    
    
    methods (Access = private)
        function RunPluginTryCatchBlock(obj, plugin_name)
            wait_dialog = obj.WaitDialogHandle;
            
            new_plugin = TDPluginInformation.LoadPluginInfoStructure(plugin_name, obj.Reporting);
            wait_dialog.ShowAndHold(['Computing ' new_plugin.ButtonText]);
            
            plugin_text = new_plugin.ButtonText;
            
            if strcmp(new_plugin.PluginType, 'DoNothing')
                obj.Dataset.GetResult(plugin_name);
            else
                [~, new_image] = obj.Dataset.GetResult(plugin_name);
                if strcmp(new_plugin.PluginType, 'ReplaceOverlay')
                    
                    if all(new_image.ImageSize == obj.ImagePanel.BackgroundImage.ImageSize) && all(new_image.Origin == obj.ImagePanel.BackgroundImage.Origin)
                        obj.ReplaceOverlayImage(new_image.RawImage, new_image.ImageType, plugin_text)
                    else
                        obj.ReplaceOverlayImageAdjustingSize(new_image, plugin_text);
                    end
                    obj.UpdateFigureTitle;
                elseif strcmp(new_plugin.PluginType, 'ReplaceQuiver')
                    if all(new_image.ImageSize(1:3) == obj.ImagePanel.BackgroundImage.ImageSize(1:3)) && all(new_image.Origin == obj.ImagePanel.BackgroundImage.Origin)
                        obj.ReplaceQuiverImage(new_image.RawImage, 4);
                    else
                        obj.ReplaceQuiverImageAdjustingSize(new_image);
                    end
                    
                elseif strcmp(new_plugin.PluginType, 'ReplaceImage')
                    obj.SetImage(new_image);
                end
            end
        end
        
        
        % Executes when application closes
        function CustomCloseFunction(obj, src, ~)
            obj.ApplicationClosing();
            
            % Note: this will delete the only reference to the application
            % object handle, triggering its destruction which will save settings
            delete(src);
            
        end
        
        function ApplicationClosing(obj)
            obj.AutoSaveMarkers;
            obj.SaveSettings;
        end        
        
        % Executes when figure is resized
        function ResizeCallback(obj, ~, ~, ~)
            obj.Resize;
        end
        
        % Item selected from the pop-up "quick load" menu
        function PopupmenuLoadCallback(obj, hObject, ~, ~)
            obj.LoadFromPopupMenu(get(hObject, 'Value'));
        end
        
        function LoadFromPopupMenu(obj, index)            
            image_info = obj.DropDownLoadMenuManager.GetImageInfoForIndex(index);
            
            % An empty image_info indicates that this dataset has already been
            % selected. This prevents data re-loading when the same dataset is
            % selected.
            % Also, due to a Matlab/Java bug, this callback may be called twice 
            % when an option is selected from the drop-down load menu using 
            % keyboard shortcuts. This will prevent the loading function from
            % being called twice
            if ~isempty(image_info)
                obj.LoadImages(image_info, obj.WaitDialogHandle);
            end            
        end
        
        % Profile checkbox
        % Enables or disables (and shows) Matlab's profiler
        function ProfileCheckboxCallback(obj, hObject, ~, ~)
            if get(hObject,'Value')
                profile on
            else
                profile viewer
            end
        end
        
        % Updates the "Show profile" check box according to the current running state
        % of the Matlab profiler
        function UpdateProfilerStatus(obj)
            profile_status = profile('status');
            if strcmp(profile_status.ProfilerStatus, 'on')
                set(obj.ProfileCheckboxHandle, 'Value', true);
            else
                set(obj.ProfileCheckboxHandle, 'Value', false);
            end
        end
        
        % Scroll wheel
        function WindowScrollWheelFcn(obj, src, eventdata)
            current_point = get(obj.FigureHandle, 'CurrentPoint');
            scroll_count = eventdata.VerticalScrollCount; % positive = scroll down
            
            % Give the plugins panel the option of processing the scrollwheel
            % input; if it isn't processed then call the old handler
            if ~obj.PluginsPanel.Scroll(scroll_count, current_point)
                obj.OldWindowScrollWheelFcn(src, eventdata);
            end
        end
        
        function MarkerPanelSelected(obj, ~, ~)
            if ~obj.MarkersHaveBeenLoaded
                wait_dialog = obj.WaitDialogHandle;
                wait_dialog.ShowAndHold('Loading Markers');
                obj.LoadMarkers;
                wait_dialog.Hide;
            end
        end
        
        function LoadImages(obj, image_info, wait_dialog)
                wait_dialog.ShowAndHold('Please wait');
            
            try
                new_dataset = obj.Ptk.CreateDatasetFromInfo(image_info);

                obj.ClearImages;
                delete(obj.Dataset);

                obj.Dataset = new_dataset;
                obj.Dataset.addlistener('PreviewImageChanged', @obj.PreviewImageChanged);
                
                image_info = obj.Dataset.GetImageInfo;
                modality = image_info.Modality;
                
                % If the modality is not CT then we load the full dataset
                load_full_data = ~(isempty(modality) || strcmp(modality, 'CT'));
                    
                % Attempt to obtain the region of interest
                if ~load_full_data
                    if obj.Dataset.IsContextEnabled(TDContext.LungROI)
                        try
                            lung_roi = obj.Dataset.GetResult('TDLungROI');
                            obj.SetImage(lung_roi);
                        catch exc
                            if TDSoftwareInfo.IsErrorCancel(exc.identifier)
                                obj.Reporting.Log('LoadImages cancelled by user');
                                load_full_data = false;
                                rethrow(exc)
                            else
                                obj.Reporting.ShowMessage('TDPTKGuiApp:CannotGetROI', ['Unable to extract region of interest from this dataset. Error: ' exc.message]);
                                load_full_data = true;
                            end
                        end
                    else
                        load_full_data = true;
                    end
                end

                % If we couldn't obtain the ROI, we load the full dataset
                if load_full_data
                    lung_roi = obj.Dataset.GetResult('TDOriginalImage');
                    obj.SetImage(lung_roi);
                    obj.Dataset.SaveData('TDOriginalImage', lung_roi);
                end
                
                obj.Settings.ImageInfo = image_info;
                
                old_infos = obj.Settings.PreviousImageInfos;
                if ~old_infos.isKey(image_info.ImageUid)
                    old_infos(image_info.ImageUid) = image_info;
                    obj.Settings.PreviousImageInfos = old_infos;
                end
                
                obj.SaveSettings;
                
                obj.UpdateFigureTitle;
                
                obj.PluginsPanel.AddAllPreviewImagesToButtons(obj.Dataset, obj.ImagePanel.Window, obj.ImagePanel.Level);

                if obj.ImagePanel.IsInMarkerMode
                    obj.LoadMarkers;                    
                end

            catch exc
                if TDSoftwareInfo.IsErrorCancel(exc.identifier)
                    obj.Reporting.ShowMessage('TDPTKGuiApp:LoadingCancelled', 'User cancelled loading');
                else
                    msgbox(exc.message, [TDSoftwareInfo.Name ': Cannot load dataset'], 'error');
                    obj.Reporting.ShowMessage('TDPTKGuiApp:LoadingFailed', ['Failed to load dataset due to error: ' exc.message]);
                end
            end
            
            obj.DropDownLoadMenuManager.UpdateQuickLoadMenu;
            wait_dialog.Hide;

        end

        function LoadMarkers(obj)
            
            new_image = obj.Dataset.LoadData(TDSoftwareInfo.MakerPointsCacheName);
            if isempty(new_image)
                disp('No previous markers found for this image');
            else
                obj.ImagePanel.MarkerPointManager.ChangeMarkerImage(new_image);
            end
            obj.MarkersHaveBeenLoaded = true;
        end
        
        
        
        function ClearImages(obj)

            if ~isempty(obj.Dataset)
                obj.AutoSaveMarkers;
                obj.MarkersHaveBeenLoaded = false;
                obj.ImagePanel.BackgroundImage.Reset;
            end
            obj.DeleteOverlays;
        end
        
        
        function DeleteOverlays(obj)
            obj.ImagePanel.ClearOverlays;
            obj.UpdateFigureTitle;
        end
        
        
        function UpdateFigureTitle(obj)
            
            figure_title = TDSoftwareInfo.Name;
            if isa(obj.ImagePanel.BackgroundImage, 'TDImage')
                patient_name = obj.ImagePanel.BackgroundImage.Title;
                if obj.ImagePanel.OverlayImage.ImageExists
                    overlay_name = obj.ImagePanel.OverlayImage.Title;
                    if ~isempty(overlay_name)
                        patient_name = [patient_name ' (' overlay_name ')'];
                    end
                end
                if ~isempty(figure_title)
                    figure_title = [patient_name ' : ' figure_title];
                end
            end
            
            % Remove HTML tags
            figure_title = regexprep(figure_title, '<.*?>','');
            
            % Set window title
            set(obj.FigureHandle, 'Name', figure_title);
        end
        
        
        function RunGuiPluginCallback(obj, ~, ~, plugin_name)
            
            wait_dialog = obj.WaitDialogHandle;
            
            plugin_info = eval(plugin_name);
            wait_dialog.ShowAndHold([plugin_info.ButtonText]);

            plugin_info.RunGuiPlugin(obj);
            
            wait_dialog.Hide;
        end
        
        
        function RunPluginCallback(obj, ~, ~, plugin_name)
            obj.RunPlugin(plugin_name);
        end
                
        function SetImage(obj, new_image)
            obj.ImagePanel.BackgroundImage = new_image;
            
            if obj.ImagePanel.OverlayImage.ImageExists
                obj.ImagePanel.OverlayImage.ResizeToMatch(new_image);
            else
                obj.ImagePanel.OverlayImage = new_image.BlankCopy;
            end
            
            if obj.ImagePanel.QuiverImage.ImageExists
                obj.ImagePanel.QuiverImage.ResizeToMatch(new_image);
            else
                obj.ImagePanel.QuiverImage = new_image.BlankCopy;
            end
        end
                
        function ReplaceOverlayImageAdjustingSize(obj, new_image, title)
            new_image.ResizeToMatch(obj.ImagePanel.BackgroundImage);
            obj.ImagePanel.OverlayImage.ChangeRawImage(new_image.RawImage, new_image.ImageType);
            obj.ImagePanel.OverlayImage.Title = title;
        end
        
        function ReplaceOverlayImage(obj, new_image, image_type, title)
            obj.ImagePanel.OverlayImage.ChangeRawImage(new_image, image_type);
            obj.ImagePanel.OverlayImage.Title = title;
        end
        
        function ReplaceQuiverImageAdjustingSize(obj, new_image)
            new_image.ResizeToMatch(obj.ImagePanel.BackgroundImage);
            obj.ImagePanel.QuiverImage.ChangeRawImage(new_image.RawImage, new_image.ImageType);
        end
        
        function ReplaceQuiverImage(obj, new_image, image_type)
            obj.ImagePanel.QuiverImage.ChangeRawImage(new_image, image_type);
        end
        
        function SaveSettings(obj)
            if ~isempty(obj.Settings)
                set(obj.FigureHandle, 'units', 'pixels');
                obj.Settings.ScreenPosition = get(obj.FigureHandle, 'Position');
                obj.Settings.SaveSettings(obj.ImagePanel, obj.Reporting);
            end
        end
        
        function delete(obj)
            obj.Reporting.Log('Closing TDPTKGui');
        end
        
        function PreviewImageChanged(obj, ~, event_data)
            plugin_name = event_data.Data;
            obj.PluginsPanel.AddPreviewImage(plugin_name, obj.Dataset, obj.ImagePanel.Window, obj.ImagePanel.Level);
        end
        
        function AutoSaveMarkers(obj)            
            if obj.ImagePanel.MarkerPointManager.MarkerImageHasChanged && obj.MarkersHaveBeenLoaded
                saved_marker_points = obj.Dataset.LoadData(TDSoftwareInfo.MakerPointsCacheName);
                current_marker_points = obj.ImagePanel.MarkerPointManager.GetMarkerImage;
                markers_changed = false;
                if isempty(saved_marker_points)
                    if any(current_marker_points.RawImage(:))
                        markers_changed = true;
                    end
                else
                    if ~isequal(saved_marker_points.RawImage, current_marker_points.RawImage)
                        markers_changed = true;
                    end
                end
                if markers_changed
                    choice = questdlg('Do you want to save the current markers?', ...
                        'Unsaved changes to markers', 'Save', 'Don''t save', 'Save');
                    switch choice
                        case 'Save'
                            obj.SaveMarkers;
                        case 'Don''t save'
                            obj.SaveMarkersBackup;
                            disp('Abandoned changes have been stored in AbandonedMarkerPoints.mat');
                    end
                end
            end
        end
        
        function Resize(obj)
            set(obj.FigureHandle, 'Units', 'Pixels');

            parent_position = get(obj.FigureHandle, 'Position');
            parent_width_pixels = parent_position(3);
            parent_height_pixels = parent_position(4);
            
            load_menu_height = 23;
            viewer_panel_height = max(1, parent_height_pixels - load_menu_height);
            viewer_panel_width = viewer_panel_height;
            
            version_panel_height = 35;
            version_panel_width = max(1, parent_width_pixels - viewer_panel_width);
            
            plugins_panel_height = max(1, parent_height_pixels - load_menu_height - version_panel_height);
            
            set(obj.UipanelImageHandle, 'Units', 'Pixels', 'Position', [1, 1, viewer_panel_width, viewer_panel_height]);
            set(obj.PopupmenuLoadHandle, 'Units', 'Pixels', 'Position', [0, parent_height_pixels - load_menu_height, parent_width_pixels, load_menu_height]);
            set(obj.UipanelVersionHandle, 'Units', 'Pixels', 'Position', [viewer_panel_width, parent_height_pixels - load_menu_height - version_panel_height, version_panel_width, version_panel_height]);
            set(obj.UipanelPluginsHandle, 'Units', 'Pixels', 'Position', [viewer_panel_width, 0, version_panel_width, plugins_panel_height]);
            obj.PluginsPanel.Resize();
            
            if ~isempty(obj.WaitDialogHandle)
                obj.WaitDialogHandle.Resize();
            end
        end
        
    end
    
    methods (Static, Access = private)
        function [filename, path_name, filter_index] = SaveImageDialogBox(path_name)
            filespec = {...
                '*.tif', 'TIF (*.tif)';
                '*.jpg', 'JPG (*.jpg)';
                };
            
            [filename, path_name, filter_index] = uiputfile(filespec, 'Save image as', fullfile(path_name, ''));
        end
    end
end