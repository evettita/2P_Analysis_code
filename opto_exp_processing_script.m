
%% LOAD DATA

expDate = '2018_12_03_exp_4';
sid = 0;

parentDir = fullfile('D:\Dropbox (HMS)\2P Data\Behavior Vids\', expDate);
savePath = fullfile('D:\Dropbox (HMS)\2P Data\Behavior Vids\', expDate, ['sid_', num2str(sid)]);

annotFileName = '_Movies\autoAnnotations.mat';

try
% ----------------  Load stim metadata -------------------------------------------------------------
infoStruct = [];
stimDataFiles = dir(fullfile(parentDir, ['metadata*sid_', num2str(sid), '*.mat']));
infoStruct.stimOnsetTimes = []; infoStruct.stimDurs = []; infoStruct.trialType = []; infoStruct.outputData = [];
for iFile = 1:numel(stimDataFiles)
    
    % Load file    
    load(fullfile(parentDir, stimDataFiles(iFile).name)); % variable "metaData" with fields 'trialDuration', 'nTrials', 'stimTypes', 'sid', 'taskFile', 'outputData'
    
    % Add block data
    infoStruct.blockData(iFile).nTrials = metaData.nTrials;
    infoStruct.blockData(iFile).stimTypes = metaData.stimTypes;
    infoStruct.blockData(iFile).taskFile = metaData.taskFile;
    infoStruct.blockData(iFile).outputData = metaData.outputData;
    
    % Add info to overall session data
    infoStruct.trialDuration = metaData.trialDuration;
    infoStruct.expDate = expDate;
    
    % Add downsampled output data broken down into trials
    currOutput = metaData.outputData';
    sampPerTrial = size(currOutput, 2) / metaData.nTrials;
    rsOutput = reshape(currOutput, size(currOutput, 1), sampPerTrial, metaData.nTrials);   % --> [channel, sample, trial]
    disp(size(rsOutput))
    infoStruct.outputData = cat(3, infoStruct.outputData, permute(rsOutput(:,1:100:end,:), [2 1 3]));    % --> [sample, channel, trial]
    
    % Add trial type info
    for iTrial = 1:metaData.nTrials
        currStim = metaData.stimTypes{iTrial};
        infoStruct.stimOnsetTimes(end + 1) = str2double(regexp(currStim, '(?<=Onset_).*(?=_Dur)', 'match'));
        infoStruct.stimDurs(end + 1) = str2double(regexp(currStim, '(?<=Dur_).*', 'match'));
        infoStruct.trialType{end + 1} = regexp(currStim, '.*(?=_Onset)', 'match', 'once');
        if strcmp(infoStruct.trialType{end}, 'NoOdor')
            infoStruct.trialType{end} = 'NoStim'; % For backwards compatibility
        end
    end%iTrial
end%iFile
infoStruct.nTrials = size(infoStruct.outputData, 3);
infoStruct.stimTypes = sort(unique(infoStruct.trialType));
infoStruct.stimSepTrials = [];
for iStim = 1:length(infoStruct.stimTypes)
    infoStruct.stimSepTrials.(infoStruct.stimTypes{iStim}) = logical(cellfun(@(x) ...
        strcmp(x, infoStruct.stimTypes{iStim}), infoStruct.trialType));
end

% ----------------  Load autoAnnotation data -------------------------------------------------------
annotData = load(fullfile(parentDir, annotFileName)); % variables 'trialAnnotations', 'annotParams', 'ftData', 'flowArr', 'goodTrials', 'behaviorLabels', 'frameInfo'
annotData.nFrames = annotData.frameInfo.nFrames;
annotData.frameTimes = annotData.frameInfo.frameTimes;
annotData.FRAME_RATE = annotData.frameInfo.FRAME_RATE;
infoStruct = setstructfields(infoStruct, annotData);


% ----------------  Load FicTrac data --------------------------------------------------------------
ftData = load_fictrac_data(infoStruct, 'sid', sid, 'ParentDir', fullfile(parentDir, '\_Movies\FicTracData'));
infoStruct.ftData = ftData;
infoStruct.goodTrials(logical(ftData.resets)) = 0;

% ---------------- Create workspace vars -----------------------------------------------------------
infoStruct = orderfields(infoStruct);
nTrials = infoStruct.nTrials;
nFrames = infoStruct.nFrames;
stimTypes = infoStruct.stimTypes;
stimOnsetTimes = infoStruct.stimOnsetTimes;
stimDurs = infoStruct.stimDurs;
trialDuration = infoStruct.trialDuration;
goodTrials = infoStruct.goodTrials;
stimSepTrials = infoStruct.stimSepTrials; s = stimSepTrials;
behaviorAnnotArr = infoStruct.trialAnnotations;
FRAME_RATE = infoStruct.FRAME_RATE;
% if ~isdir(fullfile(parentDir, '\_Movies\Analysis'))
%     mkdir(fullfile(parentDir, '\_Movies\Analysis'));
% end
if ~isdir(savePath)
    mkdir(savePath)
end
catch foldME; rethrow(foldME); end

%% SET UP PLOTTING VARIABLES

stimNames = {'EtOH\_neat', 'Benzaldehyde\_e-1'}; % 'CO2\_2e-2'
stimTrialGroups = [s.OdorA + 2 * s.OdorB];
stimGroupNames = {'OdorA', 'OdorB'};
stimShading = {[8 11]};
stimShadingColors = {'red', 'green'};
rgbStimShadeColors = [rgb(stimShadingColors{1}); rgb(stimShadingColors{2})];
% groupBounds = [1:40:nTrials]; groupBounds(2:end) = groupBounds(2:end) - 1;
groupBounds = [1, 40, 100];
%% 2D BEHAVIOR SUMMARY
saveDir = uigetdir(savePath, 'Select a save directory');

trialGroups = [];
plotTitleSuffix = '';
fileNameSuffix = '_AllTrials';
% 
% trialGroups = stimTrialGroups; 
% plotTitleSuffix = make_plotTitleSuffix(stimNames); %
% fileNameSuffix = make_fileNameSuffix(stimGroupNames);

% % GROUP BY ALTERNATING BLOCKS
% groupNames = {'Odor only', 'Odor + photostim'};
% trialGroups = zeros(1, nTrials);
% for iBound = 1:numel(groupBounds)-1
%    trialGroups(groupBounds(iBound):groupBounds(iBound + 1)) = ~mod(iBound, 2);
% end
% trialGroups(groupBounds(end):end) = ~mod(iBound + 1, 2);
% trialGroups = trialGroups + 1;
% plotTitleSuffix = make_plotTitleSuffix(groupNames);
% fileNameSuffix = '_PhotostimVsOdorOnly';

try
    
% Create plot titles
plotName = 'Behavior Annotation';
titleString = [regexprep(expDate, '_', '\\_'), '    ', [plotName, ' summary ', plotTitleSuffix]]; % regex to add escape characters
annotArr = behaviorAnnotArr;

% Create figure
f = figure(7);clf
f.Position = [-1050 45 1020 950];
f.Color = [1 1 1];
ax = gca();
[~, ax, ~] = plot_behavior_summary_2D(infoStruct, annotArr, ax, titleString, trialGroups);
ax.FontSize = 14;
ax.Title.FontSize = 12;
ax.XLabel.FontSize = 14;

% Plot stim times
hold on
[nStimEpochs, idx] = max(cellfun(@size, stimShading, repmat({1}, 1, numel(stimShading))));
for iStim = 1:nStimEpochs
    stimOnsetFrame = stimShading{idx}(iStim, 1) * FRAME_RATE;
    stimOffsetFrame = stimShading{idx}(iStim, 2) * FRAME_RATE;
    plot(ax, [stimOnsetFrame, stimOnsetFrame], ylim(), 'Color', 'k', 'LineWidth', 2)
    plot(ax, [stimOffsetFrame, stimOffsetFrame], ylim(), 'Color', 'k', 'LineWidth', 2)
end

if saveDir
    fileName = ['2D_Annotation_Summary', fileNameSuffix, '_', ...
                regexprep(expDate, {'_', 'exp'}, {'', '_'})];
    export_fig(fullfile(saveDir, fileName), '-png', f);
    if ~isdir(fullfile(saveDir, 'figFiles'))
        mkdir(fullfile(saveDir, 'figFiles'))
    end
    savefig(f, fullfile(saveDir, 'figFiles', fileName));
end
catch foldME; rethrow(foldME); end

%% 1D BEHAVIOR SUMMARY
actionNames = {'NA', 'IsoMovement', 'Locomotion'};
saveDir = uigetdir(savePath, 'Select a save directory');
actionNum = [3]; % locomotionLabel = 3; noActionLabel = 0; isoMovementLabel = 1;
actionName = actionNames{actionNum};
figTitle = regexprep([expDate, '  �  Fly ', actionName, ' throughout trial'], '_', '\\_');
cm = [];

% % ALL TRIALS
% trialGroups = [goodTrials];
% fileNameSuffix = ['_AllTrials_', actionName];
% groupNames = {'All trials'};
% 
% % GROUP BY STIM TYPE
% trialGroups = stimTrialGroups .* goodTrials;
% fileNameSuffix = [make_fileNameSuffix(stimGroupNames), '_', actionName]; 
% groupNames = stimNames;
% % % % 
% 
% % GROUP BY SINGLE BLOCKS
% groupNames = [];
% trialGroups = zeros(1, nTrials);
% for iBound = 1:numel(groupBounds)-1
%    trialGroups(groupBounds(iBound):groupBounds(iBound + 1)) = iBound;
%    groupNames{iBound} = ['Trials ', num2str(groupBounds(iBound)), '-', num2str(groupBounds(iBound + 1))];
% end
% trialGroups(groupBounds(end):end) = numel(groupBounds);
% groupNames = {'Odor only', 'Odor + photostim'};
% fileNameSuffix = '_SingleBlocks';
% cm = repmat([rgb('blue'); rgb('red')], 4, 1);

% GROUP BY ALTERNATING BLOCKS
groupNames = {'Odor only', 'Odor + photostim'};
trialGroups = zeros(1, nTrials);
for iBound = 1:numel(groupBounds)-1
   trialGroups(groupBounds(iBound):groupBounds(iBound + 1)) = ~mod(iBound, 2);
end
trialGroups(groupBounds(end):end) = ~mod(iBound + 1, 2);
trialGroups = trialGroups + 1;
fileNameSuffix = '_PhotostimVsOdorOnly';

% trialGroups(1:40) = 0;
% trialGroups(120:end) = 0;

try
f = figure(2); clf; hold on
f.Position = [-1600 300 1600 500];
f.Color = [1 1 1];

if isempty(trialGroups)
    
    % Plot summed movement data
    annotArrSum = sum(ismember(behaviorAnnotArr, actionNum), 1) ./ nTrials;
    ax = gca();
    ax.FontSize = 14;
    plot_behavior_summary_1D(infoStruct, annotArrSum(2:end-1), ax, figTitle);
    
else
    annotArrSum = [];
    yLimsAll = [];
    ax = [];
    nGroups = length(unique(trialGroups(trialGroups ~= 0)));
    if isempty(cm)
        cm = parula(nGroups);
        cm = [rgb('blue'); rgb('red'); rgb('green'); rgb('magenta'); rgb('cyan'); rgb('gold'); rgb('lime')];
    end
    for iGroup = 1:nGroups
        ax = gca();
        ax.FontSize = 14;
        colormap(jet(nGroups))
        annotArrSum = sum(ismember(behaviorAnnotArr(trialGroups == iGroup, :), actionNum), 1) ./ sum(trialGroups == iGroup);
        [plt, ~, ~] = plot_behavior_summary_1D(infoStruct, annotArrSum, 'PlotAxes', ax, 'LineColor', cm(iGroup, :));
        plt.LineWidth = 2;
        if iGroup ~= length(unique(trialGroups))
            xlabel('');
        end
    end%iGroup
    
    legend(groupNames, 'FontSize', 14, 'Location', 'Best', 'AutoUpdate', 'off')
    ax.XLim = [20 nFrames-20]; % to improve plot appearance
    ax.YLim = [0 1];
    suptitle(figTitle);
end

% Add shading during stimulus presentations
[nStimEpochs, idx] = max(cellfun(@size, stimShading, repmat({1}, 1, numel(stimShading))));
yL = ylim();
for iStim = 1:size(stimShading{idx}, 1)
    stimOnset = stimShading{idx}(iStim, 1) * FRAME_RATE;
    stimOffset = stimShading{idx}(iStim, 2) * FRAME_RATE;
    plot_stim_shading([stimOnset, stimOffset], 'Color', rgb(stimShadingColors{iStim}))
end

if saveDir
    fileName = ['1D_Annotation_Summary', fileNameSuffix, '_', ...
                regexprep(expDate, {'_', 'exp'}, {'', '_'})];
    export_fig(fullfile(saveDir, fileName), '-png', f);
    if ~isdir(fullfile(saveDir, 'figFiles'))
        mkdir(fullfile(saveDir, 'figFiles'))
    end
    savefig(f, fullfile(saveDir, 'figFiles', fileName));
end
catch foldME; rethrow(foldME); end

%% 2D FICTRAC SUMMARY

saveDir = uigetdir(savePath, 'Select a save directory');
fontSize = 12;

ftVarName = 'moveSpeed'; % 'moveSpeed', 'fwSpeed', 'yawSpeed'
sdCap = 1;
smWin = 9;
cmName = @parula;
figTitle = [regexprep(expDate, '_', '\\_'), '  �  FicTrac ', ftVarName];


% % ALL TRIALS
% trialGroups = [];
% fileNameSuffix = ['_AllTrials'];
% plotTitleSuffix = '';

% % % % % % % % 
% GROUP BY STIM TYPE
trialGroups = stimTrialGroups .* goodTrials; 
fileNameSuffix = make_fileNameSuffix(stimGroupNames);
plotTitleSuffix = make_plotTitleSuffix(stimNames);

% % GROUP BY ALTERNATING BLOCKS
% groupNames = {'Odor only', 'Odor + photostim'};
% trialGroups = zeros(1, nTrials);
% for iBound = 1:numel(groupBounds)-1
%    trialGroups(groupBounds(iBound):groupBounds(iBound + 1)) = ~mod(iBound, 2);
% end
% trialGroups(groupBounds(end):end) = ~mod(iBound + 1, 2);
% trialGroups = (trialGroups + 1) .* goodTrials;
% plotTitleSuffix = make_plotTitleSuffix(groupNames);
% fileNameSuffix = '_PhotostimVsOdorOnly';

trialGroups(110:end) = 0;
try

% Extract FicTrac data
rawData = infoStruct.ftData.(ftVarName);          % --> [frame, trial]
rawData = rawData';                                     % --> [trial, frame]
if strcmp(ftVarName, 'yawSpeed')
    plotData = abs(rad2deg(rawData .* FRAME_RATE));    	% --> [trial, frame] (deg/sec)
    figTitle = [figTitle, ' (deg/sec)'];
else
    plotData = rawData .* FRAME_RATE .* 4.5;            % --> [trial, frame] (mm/sec)
    figTitle = [figTitle, ' (mm/sec)'];
end

% Cap values at n SD above mean
capVal = mean(plotData(:), 'omitnan') + (sdCap * std(plotData(:), 'omitnan'));
plotData(plotData > capVal) = capVal;

% Smooth data
smPlotData = movmean(plotData, smWin, 2);

% Create colormap
cm = cmName(numel(unique(smPlotData)));
if ~isempty(trialGroups)
    cm = [0 0 0; cm(2:end, :)];
end

% Plot data
titleStr = [figTitle, plotTitleSuffix];
[~, ax, f] = plot_2D_summary(infoStruct, smPlotData, ...
                'trialGroups', trialGroups, ...
                'titleStr', titleStr, ...
                'sampRate', FRAME_RATE, ...
                'colormap', cm ...
                );
ax.Title.FontSize = fontSize;

% Plot stim times
colorbar
hold on

% Plot stim times
hold on
[nStimEpochs, idx] = max(cellfun(@size, stimShading, repmat({1}, 1, numel(stimShading))));
for iStim = 1:nStimEpochs
    stimOnsetFrame = stimShading{idx}(iStim, 1) * FRAME_RATE;
    stimOffsetFrame = stimShading{idx}(iStim, 2) * FRAME_RATE;
    plot(ax, [stimOnsetFrame, stimOnsetFrame], ylim(), 'Color', 'k', 'LineWidth', 2)
    plot(ax, [stimOffsetFrame, stimOffsetFrame], ylim(), 'Color', 'k', 'LineWidth', 2)
end

if saveDir
    fileName = ['2D_FicTrac_', ftVarName, '_Summary', fileNameSuffix, '_', ...
                regexprep(expDate, {'_', 'exp'}, {'', '_'})];
    export_fig(fullfile(saveDir, fileName), '-png', f);
    if ~isdir(fullfile(saveDir, 'figFiles'))
        mkdir(fullfile(saveDir, 'figFiles'))
    end
    savefig(f, fullfile(saveDir, 'figFiles', fileName));
end

catch foldME; rethrow(foldME); end

%% 1D FICTRAC SUMMARY

saveDir = uigetdir(savePath, 'Select a save directory');

includeQuiescence = 0;
if ~includeQuiescence
    fileNameSuffix = 'NoQuiescence_';
else
    fileNameSuffix = '';
end
figTitle = [expDate, '  �  Trial-Averaged FicTrac data'];
trialGroups = goodTrials';
smWin = 11;
cm = [];
% 

% % ALL TRIALS
% trialGroups = [goodTrials];
% fileNameSuffix = [fileNameSuffix, 'AllTrials'];
% groupNames = {'All trials'};


% % GROUP BY STIM TYPE
% trialGroups = stimTrialGroups .* goodTrials; 
% fileNameSuffix = [fileNameSuffix, 'StimTypeComparison']; 
% groupNames = stimNames;


% % GROUP BY SINGLE BLOCKS
% groupNames = [];
% trialGroups = zeros(1, nTrials);
% for iBound = 1:numel(groupBounds)-1
%    trialGroups(groupBounds(iBound):groupBounds(iBound + 1)) = iBound;
%    groupNames{iBound} = ['Trials ', num2str(groupBounds(iBound)), '-', num2str(groupBounds(iBound + 1))];
% end
% trialGroups(groupBounds(end):end) = numel(groupBounds);
% groupNames = {'Odor only', 'Odor + photostim'};
% fileNameSuffix = [fileNameSuffix, 'SingleBlocks'];
% cm = repmat([rgb('blue'); rgb('red')], 4, 1);
%  
% % 
% GROUP BY ALTERNATING BLOCKS
groupNames = {'Odor only', 'Odor + photostim'};
trialGroups = zeros(1, nTrials);
for iBound = 1:numel(groupBounds)-1
   trialGroups(groupBounds(iBound):groupBounds(iBound + 1)) = ~mod(iBound, 2);
end
trialGroups(groupBounds(end):end) = ~mod(iBound + 1, 2);
trialGroups = trialGroups + 1;
fileNameSuffix = [fileNameSuffix, 'PhotoStimVsOdorOnly'];

trialGroups(110:end) = 0;
try
    
xTickFR = [0:1/trialDuration:1] * (trialDuration * FRAME_RATE);
xTickLabels = [0:1/trialDuration:1] * trialDuration;
mmSpeedData = ftData.moveSpeed * FRAME_RATE * 4.5;  % --> [frame, trial] (mm/sec)
dHD = abs(rad2deg(ftData.yawSpeed * FRAME_RATE));        % --> [frame, trial] (deg/sec)
fwSpeed = ftData.fwSpeed * FRAME_RATE * 4.5;        % --> [frame, trial  (mm/sec)
nFrames = size(mmSpeedData, 1);

% Create figure
f = figure(3); clf; hold on
f.Position = [-1100 50 900 930];
f.Color = [1 1 1];

% Create axes
M = 0.02;
P = 0.00;
axVel = subaxis(3,1,1, 'S', 0, 'M', M, 'PB', 0.05, 'PL', 0.05); hold on
axFWSpeed = subaxis(3,1,2, 'S', 0, 'M', M, 'PB', 0.05, 'PL', 0.06); hold on
axYawSpeed = subaxis(3,1,3, 'S', 0, 'M', M, 'PB', 0.06, 'PL', 0.06); hold on

% Plot data
nGroups = length(unique(trialGroups(trialGroups ~= 0)));
if isempty(cm)
    cm = parula(nGroups);
    cm = [rgb('blue'); rgb('red'); rgb('green'); rgb('magenta'); rgb('cyan'); rgb('gold'); rgb('lime')];
end
for iGroup = 1:nGroups
    
    % Calculate mean values for current group
    currXYSpeed = mmSpeedData(:, trialGroups==iGroup);
    currFWSpeed = fwSpeed(:, trialGroups == iGroup);
    currYawSpeed = dHD(:, trialGroups == iGroup);
    
    if ~includeQuiescence
        currAnnotData = behaviorAnnotArr';
        currAnnotData(:, trialGroups ~= iGroup) = [];
        currXYSpeed(currAnnotData == 0) = nan;
        currFWSpeed(currAnnotData == 0) = nan;
        currYawSpeed(currAnnotData == 0) = nan;
    end
    
    % Omit outliers
    outlierCalc = @(x) mean(x) + 4 * std(x);
    currXYSpeed(currXYSpeed >= outlierCalc(mmSpeedData(:))) = nan;
    currFWSpeed(currFWSpeed >= outlierCalc(fwSpeed(:))) = nan;
    currYawSpeed(currYawSpeed >= outlierCalc(dHD(:))) = nan;
%     
    meanSpeed = smooth(mean(currXYSpeed, 2, 'omitnan'), smWin);
    meanFWSpeed = smooth(mean(currFWSpeed, 2, 'omitnan'), smWin);
    meanYawSpeed = smooth(mean(currYawSpeed, 2, 'omitnan'), smWin);
    
    % XY speed plot
    axes(axVel)
    plot(meanSpeed, 'linewidth', 2, 'color', cm(iGroup, :));
    
    % Forward speed plot
    axes(axFWSpeed)
    plot(meanFWSpeed, 'linewidth', 2, 'color', cm(iGroup,:));
        
    % Yaw speed plot
    axes(axYawSpeed)
    plot(meanYawSpeed, 'linewidth', 2, 'color', cm(iGroup,:));
    axYawSpeed.XLabel.String = 'Time (sec)';

end%iGroup

% Format axes
axVel.XTick = xTickFR;
axVel.XTickLabel = xTickLabels;
axVel.YLabel.String = 'XY Speed (mm/sec)';
axVel.FontSize = 14;
legend(axVel, groupNames, 'FontSize', 12, 'Location', 'NW', 'AutoUpdate', 'off')
axVel.XLim = [9 nFrames-5]; % to improve plot appearance
if ~isempty(stimShading)
    [nStimEpochs, idx] = max(cellfun(@size, stimShading, repmat({1}, 1, numel(stimShading))));
    for iStim = 1:size(stimShading{idx}, 1)
        stimOnset = stimShading{idx}(iStim, 1) * FRAME_RATE;
        stimOffset = stimShading{idx}(iStim, 2) * FRAME_RATE;
        plot_stim_shading([stimOnset, stimOffset], 'Color', rgb(stimShadingColors{iStim}), 'Axes', ...
            axVel);
    end
end

axFWSpeed.XTick = xTickFR;
axFWSpeed.XTickLabel = xTickLabels;
axFWSpeed.YLabel.String = 'FW Vel (mm/sec)';
axFWSpeed.FontSize = 14;
legend(axFWSpeed, groupNames, 'FontSize', 12, 'Location', 'NW', 'AutoUpdate', 'off')
axFWSpeed.XLim = [9 nFrames-5]; % to improve plot appearance
if ~isempty(stimShading)
    [nStimEpochs, idx] = max(cellfun(@size, stimShading, repmat({1}, 1, numel(stimShading))));
    for iStim = 1:size(stimShading{idx}, 1)
        stimOnset = stimShading{idx}(iStim, 1) * FRAME_RATE;
        stimOffset = stimShading{idx}(iStim, 2) * FRAME_RATE;
        plot_stim_shading([stimOnset, stimOffset], 'Color', rgb(stimShadingColors{iStim}), 'Axes', ...
            axFWSpeed);
    end
end

axYawSpeed.XTick = xTickFR;
axYawSpeed.XTickLabel = xTickLabels;
axYawSpeed.YLabel.String = 'Yaw Speed (deg/sec)';
axYawSpeed.FontSize = 14;
legend(axYawSpeed, groupNames, 'FontSize', 12, 'Location', 'NW', 'AutoUpdate', 'off')
axYawSpeed.XLim = [9 nFrames-5]; % to improve plot appearance
if ~isempty(stimShading)
    [nStimEpochs, idx] = max(cellfun(@size, stimShading, repmat({1}, 1, numel(stimShading))));
    for iStim = 1:size(stimShading{idx}, 1)
        stimOnset = stimShading{idx}(iStim, 1) * FRAME_RATE;
        stimOffset = stimShading{idx}(iStim, 2) * FRAME_RATE;
        plot_stim_shading([stimOnset, stimOffset], 'Color', rgb(stimShadingColors{iStim}), 'Axes', ...
            axYawSpeed);
    end
end

suptitle(regexprep([figTitle, '  �  ', fileNameSuffix], '_', '\\_'));
if saveDir

    % Create filename
    fileName = regexprep(['1D_FicTrac_Summary_', fileNameSuffix, '_', ...
                            regexprep(expDate, {'_', 'exp'}, {'', '_'})], '_', '\_');
    
    % Save figure files
        export_fig(fullfile(saveDir, fileName), '-png', f);
        if ~isdir(fullfile(saveDir, 'figFiles'))
            mkdir(fullfile(saveDir, 'figFiles'))
        end
        savefig(f, fullfile(saveDir, 'figFiles', fileName));
end%if

catch foldME; rethrow(foldME); end


















