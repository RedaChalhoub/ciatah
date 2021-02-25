function [externalProgramsDir] = getDirExternalPrograms(varargin)
	% Returns the directory where external programs are stored. All functions should call this to find external program directory.
	% Biafra Ahanonu
	% started: 2021.02.02 [10:55:23]
	% inputs
		%
	% outputs
		%

	% changelog
		%
	% TODO
		%

	%========================
	% DESCRIPTION
	% options.exampleOption = '';
	% get options
	% options = getOptions(options,varargin);
	% display(options)
	% unpack options into current workspace
	% fn=fieldnames(options);
	% for i=1:length(fn)
	% 	eval([fn{i} '=options.' fn{i} ';']);
	% end
	%========================

	try
		externalProgramsDir = [ciapkg.getDir() filesep '_external_programs'];
	catch err
		disp(repmat('@',1,7))
		disp(getReport(err,'extended','hyperlinks','on'));
		disp(repmat('@',1,7))
	end
end