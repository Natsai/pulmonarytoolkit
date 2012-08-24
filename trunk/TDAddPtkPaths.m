function TDAddPtkPaths
    
    % This version number should be incremented whenever new paths are added to
    % the list
    TDAddPtkPaths_Version_Number = 1;
    
    global TDPTK_PathsHaveBeenSet
    
    full_path = mfilename('fullpath');
    [path_root, ~, ~] = fileparts(full_path);
    
    if (isempty(TDPTK_PathsHaveBeenSet) || TDPTK_PathsHaveBeenSet ~= TDAddPtkPaths_Version_Number)
        
        path_folders = {};
        
        % List of folders to add to the path
        path_folders{end + 1} = 'User';
        path_folders{end + 1} = 'Components';
        path_folders{end + 1} = 'bin';
        path_folders{end + 1} = 'Gui';
        path_folders{end + 1} = 'GuiPlugins';
        path_folders{end + 1} = 'Plugins';
        path_folders{end + 1} = 'Utilities';
        path_folders{end + 1} = 'Library';
        path_folders{end + 1} = 'Interfaces';
        path_folders{end + 1} = 'Types';
        path_folders{end + 1} = 'Framework';
        path_folders{end + 1} = fullfile('External', 'gerardus', 'matlab', 'PointsToolbox');
        
        full_paths_to_add = {};
        
        % Get the full path for each folder but check it exists before adding to
        % the list of paths to add
        for i = 1 : length(path_folders)
            full_path_name = fullfile(path_root, path_folders{i});
            if exist(full_path_name, 'dir')
                full_paths_to_add{end + 1} = full_path_name;
            end
        end
        
        % Add all the paths together (much faster than adding them individually)
        addpath(full_paths_to_add{:});
        
        TDPTK_PathsHaveBeenSet = TDAddPtkPaths_Version_Number;
    end
    
    % Add additional user-specific paths specified in the file
    % User/TDAddUserPaths.m if it exists
    user_function_name = 'TDAddUserPaths';
    user_add_paths_function = fullfile(path_root, 'User', [user_function_name '.m']);
    if exist(user_add_paths_function, 'file')
        feval(user_function_name);
    end
end