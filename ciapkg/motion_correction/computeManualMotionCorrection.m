function [inputImagesTranslated, outputStruct] = computeManualMotionCorrection(inputImages,varargin)
	% Translates a marker image relative to a cell map and then allows the user to click for marker positive cells or runs automated market detection and alignment to actual cells
	% Biafra Ahanonu
	% started: 2017.12.05 [17:02:58] - branched from getMarkerLocations.m
	% inputs
		% inputImages - [x y z] where z = individual frames with image to register. By default the first frame is used as the "reference" image in green.
	% outputs
		% outputStruct.registeredMarkerImage
		% outputStruct.translationVector = {1 z} cell array containing inputs for imtranslate so users can manually correct if needed.
		% outputStruct.rotationVector = {1 z} cell array containing inputs for imrotate so users can manually correct if needed.
		% outputStruct.gammaCorrection
		% outputStruct.inputImagesCorrected
		% outputStruct.inputImagesOriginal

	% changelog
		% 2020.04.07 [19:39:24] - Updated to allow just using the register aspect of the function. Also made registering callback based.
		% 2020.04.08 [10:35:49] - Added support for rotation.
		% 2020.05.28 [08:48:57] - Slight update.
		% 2021.04.16 [10:31:29] - Add default gamma option.
		% 2021.04.27 [16:26:14] - Update to fix issue of prior figure (even after clf) maintaining previous key press and exiting, causing uiwait to fail.
	% TODO
		% Add ability to auto-crop if inputs are not of the right size them convert back to correct size after manual correction
		% inputRegisterImage - [x y nCells] - Image to register to.

	%========================
	% Int: frame to use in inputImages for register in default mode
	options.refFrame = 1;
	% Figure number for
	options.translationFigNo = 45;
	% Float: 0 and 1, threshold for cell outlines
	options.imageThreshold = 0.2;
	% Binary: 1 = make inputImages and inputRegisterImage equal dims, 0 = do not alter inputs
	options.makeInputDimsEqual = 0;
	% Binary: 1 = only register, 0 = do all steps
	options.onlyRegister = 0;
	% Binary: 1 = use outlines when registering, 0 = do not use outlines
	options.registerUseOutlines = 1;
	% Cell array of matrices: cell array of {[x y z]} matrices that should match each Z dimension in inputImages
	options.altInputImages = {};
    % Str: max or mean
    options.cellCombineType = 'max';
    % Float: default gamma.
    options.gammaCorrection = 1;
	% get options
	options = getOptions(options,varargin);
	% display(options)
	% unpack options into current workspace
	% fn=fieldnames(options);
	% for i=1:length(fn)
	% 	eval([fn{i} '=options.' fn{i} ';']);
	% end
	%========================

	try
		outputStruct.success = 0;

		% If user inputs a cell, convert to matrix where each z-dimension represents max projection of each cell
		if iscell(inputImages)
			disp('Converting input cells into max-projection matrix')
			disp(['inputImages: ' num2str(size(inputImages))])
			% If user has not input alternative images but input cell array of images
			if isempty(options.altInputImages)
				switchInputImagesBack = 1;
				options.altInputImages = inputImages;
			else
				switchInputImagesBack = 0;
            end
            switch options.cellCombineType
                case 'max'
                    inputImages = cellfun(@(x) nanmax(x,[],3),inputImages,'UniformOutput',false);
                case 'mean'
                    inputImages = cellfun(@(x) nanmean(x,3),inputImages,'UniformOutput',false);
                otherwise
                    inputImages = cellfun(@(x) nanmax(x,[],3),inputImages,'UniformOutput',false);
            end                
			inputImages = cat(3,inputImages{:});
			disp(['inputImages: ' num2str(size(inputImages))])
		else
			switchInputImagesBack = 0;
		end

		% Get register frame
		inputRegisterImage = inputImages(:,:,options.refFrame);

		% downsample marker reference image as needed
		if options.makeInputDimsEqual==1
			[inputImages] = downsampleMovie(inputImages,'downsampleX',size(inputRegisterImage,1),'downsampleY',size(inputRegisterImage,2),'downsampleDimension','space');
		end

		% Determine whether to register each inputImages frame as representative of how to translate each matrix in options.altInputImages
		if ~isempty(options.altInputImages)
			inputImagesTranslated = NaN(size(inputImages));
			for frameNo = 1:size(inputImages,3)
				fprintf('Running %d/%d input image...\n',frameNo,size(inputImages,3));
				[outputStruct] = subfxnRegisterImage(inputImages(:,:,frameNo),inputRegisterImage,options,outputStruct,frameNo,size(inputImages,3));

				outputStruct.altInputImages{frameNo} = NaN(size(options.altInputImages{frameNo}));
				fprintf('Translating alt input images...\n')
				inputImagesTranslated(:,:,frameNo) = imtranslate(inputImages(:,:,frameNo),outputStruct.translationVector{frameNo});
				inputImagesTranslated(:,:,frameNo) = imrotate(inputImages(:,:,frameNo),outputStruct.rotationVector{frameNo},'nearest','crop');
				outputStruct.translationVector{frameNo}
				for imgNo = 1:size(outputStruct.altInputImages{frameNo},3)
					% figure;
					% 	subplot(1,2,1)
					% 		imagesc(options.altInputImages{frameNo}(:,:,imgNo)); axis equal tight
					% 	subplot(1,2,2)
					% 		imagesc(imtranslate(options.altInputImages{frameNo}(:,:,imgNo),outputStruct.translationVector{frameNo})); axis equal tight
					% 	pause
					outputStruct.altInputImages{frameNo}(:,:,imgNo) = imtranslate(options.altInputImages{frameNo}(:,:,imgNo),outputStruct.translationVector{frameNo});
					outputStruct.altInputImages{frameNo}(:,:,imgNo) = imrotate(outputStruct.altInputImages{frameNo}(:,:,imgNo),outputStruct.rotationVector{frameNo},'nearest','crop');
				end
				% figure;imagesc(max(outputStruct.altInputImages{frameNo},[],3))
			end
		else
			% First register the inputImages by moving relative to inputRegisterImage
			for frameNo = 1:size(inputImages,3)
                [outputStruct] = subfxnRegisterImage(inputImages(:,:,frameNo),inputRegisterImage,options,outputStruct,frameNo,size(inputImages,3));
                inputImagesTranslated = NaN(size(inputImages));
				inputImagesTranslated(:,:,frameNo) = imtranslate(inputImages(:,:,frameNo),outputStruct.translationVector{frameNo});
                if outputStruct.rotationVector{frameNo}==0
                else
                    inputImagesTranslated(:,:,frameNo) = imrotate(inputImagesTranslated(:,:,frameNo),outputStruct.rotationVector{frameNo},'nearest','crop');
                end
                outputStruct.inputImagesCorrected{frameNo} = inputImagesTranslated(:,:,frameNo);
                outputStruct.inputImagesOriginal{frameNo} = inputImages(:,:,frameNo);
			end
		end

		if switchInputImagesBack==1
			inputImagesTranslated = outputStruct.altInputImages;
		end

		if options.onlyRegister==1
			return
		end

		outputStruct.success = 1;
	catch err
		display(repmat('@',1,7))
		disp(getReport(err,'extended','hyperlinks','on'));
		display(repmat('@',1,7))
	end
end
function [outputStruct] = subfxnRegisterImage(inputImages,inputRegisterImage,options,outputStruct,imgNo,imgN)
	inputRegisterImageCellmap = createObjMap(inputRegisterImage);

	if options.registerUseOutlines==1
		[thresholdedImages boundaryIndices] = thresholdImages(inputRegisterImage,'binary',1,'getBoundaryIndex',1,'threshold',options.imageThreshold,'imageFilter','median');
		inputRegisterImageOutlines = zeros([size(inputRegisterImageCellmap)]);
		inputRegisterImageOutlines([boundaryIndices{:}]) = 1;
	else
		inputRegisterImageOutlines = normalizeVector(single(inputRegisterImage(:,:,1)),'normRange','zeroToOne');
    end
    inputRegisterImageOutlinesOriginal = inputRegisterImageOutlines;

	[figHandle figNo] = openFigure(options.translationFigNo, '');
	% Force current character to be a new figure.
    set(gcf,'currentch','3');
	clf
	% normalize input marker image
	inputImages = normalizeVector(single(inputImages),'normRange','zeroToOne');
	inputImagesOriginal = inputImages;
	gammaCorrection = options.gammaCorrection;
    gammaCorrectionRef = options.gammaCorrection;
	inputImages = imadjust(inputImages,[],[],gammaCorrection);
	inputRegisterImage = imadjust(inputRegisterImage,[],[],gammaCorrectionRef);
	continueRegistering = 1;
	translationVector = [0 0];
	rotationVector = [0];
	% zoom on;
	% set(figHandle, 'KeyPressFcn', @(source,eventdata) figure(figHandle));
	set(figHandle, 'KeyPressFcn', @(source,eventdata) subfxnRespondUser(source,eventdata));
	figure(figHandle)
	rgbImage = subfxncreateRgbImg();
	imgTitleFxn = @(imgNo,imgN,gammaCorrection,gammaCorrectionRef,translationVector,rotationVector) sprintf('Image %d/%d\nup/down/left/right arrows for translation | "A" = rotate left, "S" = rotate right | f to finish\n1/2 keys for image gamma down/up | gamma = %0.3f |  gamma(ref) = %0.3f | translation %d %d | rotation %d\npurple = reference image, green = image to manually translate',imgNo,imgN,gammaCorrection,gammaCorrectionRef,translationVector,rotationVector);
	
    imgTitle = imgTitleFxn(imgNo,imgN,gammaCorrection,gammaCorrectionRef,translationVector,rotationVector);
	imgHandle = imagesc(rgbImage);
	axis equal tight
	box off;
	imgTitleHandle = title(imgTitle);
	subfxnRespondUser([],[]);
	uiwait(figHandle)

	outputStruct.registeredMarkerImage{imgNo} = imtranslate(inputImagesOriginal,translationVector);
	outputStruct.translationVector{imgNo} = translationVector;
	outputStruct.rotationVector{imgNo} = rotationVector;
	outputStruct.gammaCorrection{imgNo} = translationVector;
	outputStruct.inputImagesCorrected{imgNo} = inputImages;
	outputStruct.inputImagesOriginal{imgNo} = inputImagesOriginal;

	function rgbImage = subfxncreateRgbImg()
		rgbImage(:,:,1) = inputRegisterImageOutlines; %red
		rgbImage(:,:,2) = inputImages; %green
		if options.registerUseOutlines==1
		else
		end
		% rgbImage(:,:,3) = zeros([size(rgbImage(:,:,2))]); %blue
		rgbImage(:,:,3) = inputRegisterImageOutlines; %blue
	end

	function subfxnRespondUser(src,event)
		figure(figHandle)
		subfxnDrawImg()
		
		% pause
		[tDelta, continueRegistering, gDelta, rDelta, gDeltaRef] = subfxnRespondToUserInputTranslation();
        set(gcf,'CurrentCharacter','0');
		translationVector = translationVector+tDelta;
		rotationVector = rotationVector+rDelta;
        
        gammaCorrection = subfxnGammaUpdate(gammaCorrection,gDelta);
        gammaCorrectionRef = subfxnGammaUpdate(gammaCorrectionRef,gDeltaRef);
		
		inputImages = imtranslate(inputImagesOriginal,translationVector);
		inputImages = imrotate(inputImages,rotationVector,'nearest','crop');
		% if rDelta~=0
		% end
		inputImages = imadjust(inputImages,[],[],gammaCorrection);
        inputRegisterImageOutlines = inputRegisterImageOutlinesOriginal;
		inputRegisterImageOutlines = imadjust(inputRegisterImageOutlines,[],[],gammaCorrectionRef);
        
        subfxnDrawImg()
        
		if continueRegistering==0
			close(figHandle)
		end
    end
    function subfxnDrawImg()
        rgbImage = subfxncreateRgbImg();
		% imagesc(rgbImage);box off;
		set(imgHandle,'Cdata',rgbImage);
		imgTitle = imgTitleFxn(imgNo,imgN,gammaCorrection,gammaCorrectionRef,translationVector,rotationVector);
		set(imgTitleHandle,'String',imgTitle);
		% title(imgTitle)
		% imagesc(inputImages)
		drawnow
    end
end
function gammaCorrection = subfxnGammaUpdate(gammaCorrection,gDelta)
    if gammaCorrection<=1
        gDelta = gDelta/10;
    else
    	gDelta = gDelta/5;
        % gammaCorrection = gammaCorrection+round(gammaCorrection-round(gammaCorrection));
    end
    gammaCorrection = gammaCorrection+gDelta;
    if gammaCorrection<0
        gammaCorrection = 0;
    end
end
function [tDelta, continueLoop, gDelta, rDelta, gDeltaRef] = subfxnRespondToUserInputTranslation()
	continueLoop = 1;
	% translationDirection []
	% set(gcf,'currentch','3');
    % keyIn = get(gcf,'CurrentCharacter');
    % keyIn = wait(get(gcf,'CurrentCharacter'));
    % [x,y,reply]=ginput(1);
    % pause
	% while strcmp(keyIn,'3')
        % keyIn
    % end
	% reply = double(keyIn);
    % set(gcf,'currentch','3');
    reply = get(gcf,'CurrentCharacter');
    tDelta = [0 0];
    gDelta = 0;
    gDeltaRef = 0;
    rDelta = 0;
    reply = double(reply);

    % decide what to do based on input (not a switch due to multiple comparisons)
    if isequal(reply, 31)
        % down key
        tDelta = [0, 1];
        % inputImages = imtranslate(inputImages,[0, 1]);
    elseif isequal(reply, 30)
    	% up key
    	tDelta = [0, -1];
    	% inputImages = imtranslate(inputImages,[0, -1]);
    elseif isequal(reply, 28)
        % go back, left
        tDelta = [-1, 0];
        % inputImages = imtranslate(inputImages,[-1, 0]);
    elseif isequal(reply, 29)
        % go forward, right
        tDelta = [1, 0];
        % inputImages = imtranslate(inputImages,[1, 0]);
    elseif isequal(reply, 49)
        % 1 - gamma down
        gDelta = -1;
    elseif isequal(reply, 50)
        % 2 - gamma up
        gDelta = 1;
    elseif isequal(reply, 51)
        % 3 - gamma down, reference image
        gDeltaRef = -1;
    elseif isequal(reply, 52)
        % 4 - gamma up
        gDeltaRef = 1;
    elseif isequal(reply, 115)
        % s - rotate right
        rDelta = -1;
    elseif isequal(reply, 97)
        % a - rotate left
        rDelta = 1;
    elseif isequal(reply, 102)
        % user clicked 'f' for finished, exit loop
        continueLoop = 0;
        % movieDecision = questdlg('Are you sure you want to exit?', ...
        %     'Finish sorting', ...
        %     'yes','no','yes');
        % if strcmp(movieDecision,'yes')
        %     saveData=1;
        % end
    else
        % forward=1;
        % valid(i) = 1;
    end
end