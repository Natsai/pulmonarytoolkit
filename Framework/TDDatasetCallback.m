classdef TDDatasetCallback < handle
    % TDDatasetCallback. Used by plugins to obtain results and associated data for a particular dataset.
    %
    %     This class is used by plugins to run calculations and fetch cached
    %     results associated with a dataset. The difference between TDDataset 
    %     and TDDatasetCallback is that TDDataset is called from outside the 
    %     toolkit, whereas TDDatasetCallback is called by plugins during their 
    %     RunPlugin() call. TDDataset calls TDDatasetCallback, but provides 
    %     additional progress and error reporting and dependency tracking.
    %
    %     You should not create this class directly. An instance of this class
    %     is given to plugins during their RunPlugin() function call.
    %
    %     Example: 
    %
    %     classdef MyPlugin < TDPlugin
    %
    %     methods (Static)
    %         function results = RunPlugin(dataset_callback, reporting)
    %             ...
    %             airway_results = dataset_callback.GetResult('TDAirways');
    %             ...
    %         end
    %     end
    %
    %
    %     Licence
    %     -------
    %     Part of the TD Pulmonary Toolkit. http://code.google.com/p/pulmonarytoolkit
    %     Author: Tom Doel, 2012.  www.tomdoel.com
    %     Distributed under the GNU GPL v3 licence. Please see website for details.
    %

    

    properties (Access = private)
        LinkedDatasetChooser  % Sends the API calls to the correct dataset
        DatasetCallStack       % Handle to the current call stack for the primary dataset
    end
    
    methods
        function obj = TDDatasetResults(linked_dataset_chooser, dataset_call_stack)
            obj.DatasetCallStack = dataset_call_stack;
            obj.LinkedDatasetChooser = linked_dataset_chooser;
        end

        % RunPlugin: Returns the results of a plugin. If a valid result is cached on disk,
        % this wil be returned provided all the dependencies are valid.
        % Otherwise the plugin will be executed and the new result returned.
        % The optional context parameter specifies the region of interest to which the output result will be framed.
        % The dataset_uid argument specifies the name (or UID) of the linked
        % dataset from which the result will be fetched - if empty or not
        % specified then the primary dataset is used.
        % Specifying a second output argument produces a representative image from
        % the results. For plugins whose result is an image, this will generally be the
        % same as the results.
        function [result, output_image] = GetResult(obj, plugin_name, context, dataset_name)
            if nargin < 3
                context = [];
            end
            if nargin < 4
                dataset_name = [];
            end
            if nargout > 1
                [result, output_image] = obj.LinkedDatasetChooser.GetResult(plugin_name, obj.DatasetCallStack, context, dataset_name);
            else
                result = obj.LinkedDatasetChooser.GetResult(plugin_name, obj.DatasetCallStack, context, dataset_name);
            end
        end

        % Returns a TDImageInfo structure with image information, including the
        % UID, filenames and file path
        function image_info = GetImageInfo(obj, dataset_name)
            if nargin < 2
                dataset_name = [];
            end
            image_info = obj.LinkedDatasetChooser.ImageInfo(dataset_name);
        end
        
        % Returns an empty template image for the specified context
        % See TDImageTemplates.m for valid contexts
        function template_image = GetTemplateImage(obj, context, dataset_name)
            if nargin < 3
                dataset_name = [];
            end
            template_image = obj.LinkedDatasetChooser.GetTemplateImage(context, dataset_name);
        end
        
        % Check to see if a context has been disabled for this dataset, due to a 
        % failure when running the plugin that generates the template image for 
        % that context.
        function context_is_enabled = IsContextEnabled(obj, context, dataset_name)
            if nargin < 3
                dataset_name = [];
            end
            context_is_enabled = obj.LinkedDatasetChooser.IsContextEnabled(context, dataset_name);
        end
        
        % Returns if this dataset is a gas MRI type
        function is_gas_mri = IsGasMRI(obj, dataset_name)
            if nargin < 2
                dataset_name = [];
            end
            is_gas_mri = obj.LinkedDatasetChooser.IsGasMRI(dataset_name);
        end
    end
end
