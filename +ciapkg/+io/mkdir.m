function [success] = mkdir(inputPath,varargin)
	% Make a directory, check if it already exists or is valid.
	% Biafra Ahanonu
	% started: 2020.09.15 [20:29:40]
	% inputs
		%
	% outputs
		%

	% changelog
		% 2021.08.08 [19:30:20] - Updated to handle CIAtah v4.0 switch to all functions inside ciapkg package.
	% TODO
		%

	import ciapkg.api.* % import CIAtah functions in ciapkg package API.

	% ========================
	% DESCRIPTION
	options.exampleOption = '';
	% get options
	options = getOptions(options,varargin);
	% display(options)
	% unpack options into current workspace
	% fn=fieldnames(options);
	% for i=1:length(fn)
	% 	eval([fn{i} '=options.' fn{i} ';']);
	% end
	% ========================

	try
		success = 0;
		if ~exist(inputPath,'dir')
			fprintf('Creating directory: %s.\n',inputPath);
			mkdir(inputPath)
		else
			fprintf('Directory already exists: %s.\n',inputPath);
		end
		success = 1;
	catch err
		success = 1;
		disp(repmat('@',1,7))
		disp(getReport(err,'extended','hyperlinks','on'));
		disp(repmat('@',1,7))
	end
end
