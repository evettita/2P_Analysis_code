% 
% parentDir = 'D:\Dropbox (HMS)\2P Data\Imaging Data\20191205-2_38A11_ChR_60D05_7f\ProcessedData';
% analysisDir = 'D:\Dropbox (HMS)\2P Data\Imaging Data\Analysis';
% load(fullfile(parentDir, 'analysis_data.mat'));

%% COMBINE DATA FROM A BLOCK OF COMPATIBLE TRIALS

blTrials = [1:17];


flowOpts = [];

flowOpts.flowSmWin = 30;
flowOpts.moveThresh = 0.08;
moveDistThresh = 2;

bl = extract_block_data(mD, blTrials, flowOpts);

%% PLOT SUMMARY OF MOVEMENT THROUGHOUT EXPERIMENT

saveFig = 1;

% Heatmap of slightly smoothed flow throughout experiment
f = figure(1);clf;
f.Color = [1 1 1];
ax = gca;
allFlow = bl.meanVolFlow;
allFlow([1:5, size(allFlow, 1)-5:size(allFlow, 1)], :) = nan;
allFlowSm = smoothdata(allFlow, 1, 'gaussian', 4, 'omitnan');
allFlowSm = repeat_smooth(allFlow, 20, 'dim', 1, 'smwin', 5);
imagesc([0, td.trialDuration], [1, numel(bl.trialNum)], allFlowSm')
title('Optic flow')
ax.YTick = 1:numel(bl.trialNum);
xlabel('Time (sec)')
ylabel('Trial')
ax.FontSize = 12;

% Plot avg flow value and percentage of movement vols for each trial
f = figure(2); clf; hold on;
f.Color = [1 1 1];
f.Position(3:4) = [1200 400];
ax = subaxis(1, 1, 1, 'mt', 0.1, 'mb', 0.16, 'ml', 0.08, 'mr', 0.08); hold on
avgTrialFlow = mean(allFlow, 1, 'omitnan');
plotX = 1:numel(avgTrialFlow);
plot(plotX, avgTrialFlow, '-o', 'color', 'b', 'linewidth', 1, 'markersize', 8)
ax.YColor = [0 0 1];
stimTrials = find([bl.usingOptoStim]);
for iStim = 1:numel(stimTrials)
    currTrialInd = stimTrials(iStim);
    if bl.usingPanels(currTrialInd)
        shadeColor = [0 1 0];
    else
        shadeColor = [1 0 0];
    end
    plot_stim_shading([currTrialInd - 0.5, currTrialInd + 0.5], 'color', shadeColor);
end
ax.FontSize = 12;
xlabel('Trial', 'fontsize', 16)
xlim([0 plotX(end) + 1])
ax.XTick = 1:numel(bl.trialNum);
ax.XTickLabel = [bl.trialNum];
smFlow = repeat_smooth(allFlow, 20, 'dim', 1, 'smwin', flowOpts.flowSmWin);
smFlow = smFlow - min(smFlow(:));
moveVols = smFlow > flowOpts.moveThresh;
trialMovePercent = (sum(moveVols) ./ size(moveVols, 1)) * 100;
ylabel('Mean optic flow (AU)', 'fontsize', 16)

% Plot proportion of volumes when fly was moving in each trial
yyaxis('right');
ax.YColor = [1 0 0];
ylabel('% movement', 'fontsize', 16)
plot(trialMovePercent, '-*', 'color', 'r', 'linewidth', 1, 'markersize', 10)
ylim([0 100])
yyaxis('left');
ax.YColor = [0 0 1];

% Add title
figTitleStr = [bl.expID, '  -  Fly movement summary (green = opto + visual, red = opto only)'];
t = title(figTitleStr);
t.Position(2) = t.Position(2) * 1.02;

% Save figure
saveFileName = 'fly_movement_summary';
if saveFig
   saveDir = fullfile(analysisDir, bl.expID);
   save_figure(f, saveDir, saveFileName);
end

%% PLOT SINGLE-TRIAL HEATMAPS FOR ENTIRE BLOCK

saveFig = 0;

omitMoveVols = 1;

sourceData = bl.wedgeRawFlArr;
sourceData = bl.wedgeDffArr;
% sourceData = bl.wedgeZscoreArr;
sourceData = bl.wedgeExpDffArr;


% Generate figure labels and save file name
if isequal(sourceData, bl.wedgeDffArr)
    figTitleText = 'dF/F';
    saveFileName = 'single_trial_heatmaps_dff';
elseif isequal(sourceData, bl.wedgeRawFlArr)
    figTitleText = 'raw F';
    saveFileName = 'single_trial_heatmaps_rawF';
elseif isequal(sourceData, bl.wedgeZscoreArr)
    figTitleText = 'Z-scored dF/F';
    saveFileName = 'single_trial_heatmaps_zscored-dff';
elseif isequal(sourceData, bl.wedgeExpDffArr)
    figTitleText = 'full exp dF/F';
    saveFileName = 'single_trial_heatmaps_exp-dff';
else
    errordlg('Error: sourceData mismatch');
end

% Replace volumes when fly was moving with nan if necessary
if omitMoveVols
   moveDistThreshVols = round(moveDistThresh * bl.volumeRate);
   moveDistArr = permute(repmat(bl.moveDistVols, 1, 1, 8), [1 3 2]);
   sourceData(moveDistArr < moveDistThreshVols) = nan; 
   saveFileName = [saveFileName, '_no-movement'];
end

nTrials = numel([bl.trialNum]);

% To give all figures the same color scale
sourceData(1, 1, :) = min(as_vector(sourceData(:, :, ~[bl.usingOptoStim])), [], 'omitnan');
sourceData(end, end, :) = max(sourceData(:), [], 'omitnan');

f = figure(10);clf;
f.Color = [1 1 1];
colormap('parula')
for iTrial = 1:nTrials 
    
   subaxis(nTrials, 4, [1:3] + (4 * (iTrial - 1)), 'mt', 0, 'mb', 0.06, 'sv', 0.001, 'mr', 0.07);
   
   imagesc([0, bl.trialDuration], [1, 8], smoothdata(sourceData(:, :, iTrial), 1, 'gaussian', 3)');
   
   % Fill in opto stim trials with solid color
   ax = gca;
   ax.FontSize = 12;
   if bl.usingOptoStim(iTrial) && bl.usingPanels(iTrial)
       colormap(ax, [0 1 0])
   elseif bl.usingOptoStim(iTrial)
       colormap(ax, [1 0 0])
   end
   
   % Label X axis on final trial
   if iTrial < nTrials
       ax.XTickLabel = [];
   else
       xlabel('Time (sec)', 'FontSize', 12);
   end
   
   % Label each plot with trial number
   ax.YTickLabel = [];
   t = ylabel(num2str(bl.trialNum(iTrial)), 'rotation', 0, 'FontSize', 12);
   t.HorizontalAlignment = 'right';
   t.VerticalAlignment = 'middle';
   t.Position(1) = t.Position(1) * 2;
   
   
   % Add fly movement summary plot to the side of each trial
   ax = subaxis(nTrials, 4, 4*iTrial);
   normTrialFlow = avgTrialFlow ./ max(avgTrialFlow);
%    b = barh([normTrialFlow(iTrial), trialMovePercent(iTrial) / 100; nan, nan]);
   b = barh(2, trialMovePercent(iTrial) / 100, 'facecolor', [0.75 0.1 0.1]);
   ax.YLim = [0.5 3.5];
   ax.XLim = [0 1];
   ax.YTickLabel = [];

   if iTrial < nTrials
       ax.XTickLabel = [];
   else
       ax.XTick = [0 1];
       ax.XTickLabel = [0 100];
       xlabel('% movement')
   end
   
end

% Add Y-axis label to entire figure
tAx = axes(f, 'Position', [0 0 1 1]);
t = text(tAx, 0.03, 0.5, 'Trial', 'units', 'normalized');
t.Rotation = 90;
t.FontSize = 14;
tAx.Visible = 'off';

% Add figure title
figTitleStr = {[bl.expID, '  -  single trial ', figTitleText, ' across EB wedges'], ...
        'green = opto + visual, red = opto only'};
if omitMoveVols
    figTitleStr = [figTitleStr(1), {['Excl. volumes within ', num2str(moveDistThresh), ...
            ' sec of movement']}, figTitleStr{2}];
end
h = suptitle(figTitleStr);
h.FontSize = 14;

% Save figure
if saveFig
   saveDir = fullfile(analysisDir, bl.expID);
   save_figure(f, saveDir, saveFileName);
end

%% ===================================================================================================
%% Plot tuning heatmaps for each wedge across trials
%===================================================================================================
% opts = [];

saveFig = 1;

omitMoveVols = 1;

showStimTrials = 0;

sourceData = bl.wedgeRawFlArr;
sourceData = bl.wedgeDffArr;
% sourceData = bl.wedgeZscoreArr;
sourceData = bl.wedgeExpDffArr;


% Generate figure labels and save file name
if isequal(sourceData, bl.wedgeDffArr)
    figTitleText = 'dF/F';
    saveFileName = '2D_tuning_dff';
elseif isequal(sourceData, bl.wedgeRawFlArr)
    figTitleText = 'raw F';
    saveFileName = '2D_tuning_rawF';
elseif isequal(sourceData, bl.wedgeZscoreArr)
    figTitleText = 'Z-scored dF/F';
    saveFileName = '2D_tuning_zscored-dff';
elseif isequal(sourceData, bl.wedgeExpDffArr)
    figTitleText = 'full exp dF/F';
    saveFileName = '2D_tuning_exp-dff';
else
    errordlg('Error: sourceData mismatch');
end

% Replace volumes when fly was moving with nan if necessary
if omitMoveVols
   moveDistThreshVols = round(moveDistThresh * bl.volumeRate);
   moveDistArr = permute(repmat(bl.moveDistVols, 1, 1, 8), [1 3 2]);
   sourceData(moveDistArr < moveDistThreshVols) = nan; 
   saveFileName = [saveFileName, '_no-movement'];
end

nTrials = numel(bl);

% Get mean panels pos data
panelsPosVols = [];
for iVol = 1:size(sourceData, 1)
    [~, currVol] = min(abs(bl.panelsFrameTimes - bl.volTimes(iVol)));
    panelsPosVols(iVol) = bl.panelsPosX(currVol);
end
meanData = [];
for iPos = 1:numel(unique(bl.panelsPosX))
    meanData(iPos, :, :) = ...
            mean(sourceData(panelsPosVols == (iPos - 1), :, :), 1, 'omitnan'); % --> [barPos, wedge, trial]    
end
meanDataSmooth = smoothdata(meanData, 1, 'gaussian', 3, 'omitnan');

% Determine subplot grid size
nPlots = size(meanDataSmooth, 2);
if nPlots == 3
    plotPos = [2 2]; % Because [1 3] looks bad
else
    plotPos = numSubplots(nPlots);
end

% Create figure and plots
f = figure(1);clf;
f.Color = [1 1 1];
for iPlot = 1:nPlots
    subaxis(plotPos(1), plotPos(2), iPlot, 'ml', 0.05, 'mr', 0.05);
    
    currData = squeeze(meanDataSmooth(:, iPlot, :)); % --> [barPos, trial]
    if ~showStimTrials
        currData = currData(:, ~[bl.usingOptoStim]);
    end
    currDataShift = [currData(92:96, :); currData(1:91, :)];
    
    % Plot data
    plotX = -180:3.75:(180 - 3.75);
    imagesc(plotX, [1 size(currData, 2)], ...
            smoothdata(currDataShift, 1, 'gaussian', 3)');
    hold on; plot([0 0], [0 size(currData, 2) + 1], 'color', 'k', 'linewidth', 2)
    ylim([0.5 size(currData, 2) + 0.5])
%     colorbar
    xlabel('Bar position (degrees from front of fly)');
    ylabel('Trial');
    
    if showStimTrials
        % Label opto stim trials
        optoStimTrials = find([bl.usingOptoStim]);
        for iTrial = 1:numel(optoStimTrials)
            if bl.usingPanels(optoStimTrials(iTrial))
                lineColor = 'green';
            else
                lineColor = 'red';
            end
            xL = xlim() + [2 -2];
            plotX = [xL(1), xL(2), xL(2), xL(1), xL(1)];
            plotY = [-0.5 -0.5 0.5 0.5 -0.5] + optoStimTrials(iTrial);
            plot(plotX, plotY, 'color', lineColor, 'linewidth', 1.5)
            
        end
        
        % Add Y tick labels
        ax = gca;
        ax.YTick = 1:size(currData, 2);
        ax.YTickLabels = blTrials;
        
    else
        % Indicate missing opto stim trials
            skippedTrials = 0;
            optoStimTrials = find([bl.usingOptoStim]);
            for iTrial = 1:numel(optoStimTrials)
                plotY = optoStimTrials(iTrial) - skippedTrials - 0.5;
                skippedTrials = skippedTrials + 1;
                if bl.usingPanels(optoStimTrials(iTrial))
                    lineColor = 'green';
                else
                    lineColor = 'red';
                end
                xL = xlim;
                plot(xL, [plotY, plotY], 'color', lineColor, 'linewidth', 2);
            end
            
            % Skip omitted trial numbers in Y tick labels
            ax = gca();
            ax.YTick = 1:numel(bl.usingOptoStim);
            yTickLabel = blTrials;
            ax.YTickLabel = yTickLabel(~bl.usingOptoStim);
            
    end%if
end%iPlot

% Add figure title
figTitleStr = {[bl.expID, '  -  Visual tuning of EB wedges (mean ', figTitleText, ')'], ...
        'Green line  =  trial with opto + visual stim', ...
        '  Red line  = trial with opto stim only'};
if omitMoveVols
    figTitleStr{1} = [figTitleStr{1}, '  -  excluding volumes within ', num2str(moveDistThresh), ...
            ' sec of movement'];
end
h = suptitle(figTitleStr);
h.FontSize = 14;
    
% Save figure
if saveFig
   saveDir = fullfile(analysisDir, bl.expID);
   save_figure(f, saveDir, saveFileName);
end

%% ===================================================================================================    
%% Plot as lines instead of using imagesc
% ===================================================================================================

saveFig = 1;

omitMoveVols = 1;

smWin = 3;

sourceData = bl.wedgeRawFlArr;
sourceData = bl.wedgeDffArr;
% sourceData = bl.wedgeZscoreArr;
% sourceData = bl.wedgeExpDffArr;


figSize = [];
figSize = [1250 980];

% Generate figure labels and save file name
if isequal(sourceData, bl.wedgeDffArr)
    figTitleText = 'dF/F';
    saveFileName = 'tuning_curves_dff';
elseif isequal(sourceData, bl.wedgeRawFlArr)
    figTitleText = 'raw F';
    saveFileName = 'tuning_curves_rawF';
elseif isequal(sourceData, bl.wedgeZscoreArr)
    figTitleText = 'Z-scored dF/F';
    saveFileName = 'tuning_curves_zscored-dff';
elseif isequal(sourceData, bl.wedgeExpDffArr)
    figTitleText = 'full exp dF/F';
    saveFileName = 'tuning_curves_exp-dff';
else
    errordlg('Error: sourceData mismatch');
end

% Replace volumes when fly was moving with nan if necessary
if omitMoveVols
   moveDistThreshVols = round(moveDistThresh * bl.volumeRate);
   moveDistArr = permute(repmat(bl.moveDistVols, 1, 1, 8), [1 3 2]);
   sourceData(moveDistArr < moveDistThreshVols) = nan; 
   saveFileName = [saveFileName, '_no-movement'];
end

% Get mean panels pos data
panelsPosVols = [];
for iVol = 1:size(sourceData, 1)
    [~, currVol] = min(abs(bl.panelsFrameTimes - bl.volTimes(iVol)));
    panelsPosVols(iVol) = bl.panelsPosX(currVol);
end
plotData = [];
for iPos = 1:numel(unique(bl.panelsPosX))
    plotData(iPos, :, :) = ...
            mean(sourceData(panelsPosVols == (iPos - 1), :, :), 1, 'omitnan'); % --> [barPos, wedge, trial]    
end

% Shift data so center of plot is directly in front of the fly
shiftData = cat(1, plotData(92:96, :, :), plotData(1:91, :, :));
shiftDataSm = repeat_smooth(shiftData, 10, 'smWin', smWin);

% Offset data so that each plot is centered at zero
shiftDataOffset = [];
for iTrial = 1:size(shiftDataSm, 3)
   for iWedge = 1:size(shiftDataSm, 2)
      currData = shiftDataSm(:, iWedge, iTrial); % --> [barPos]
      shiftDataOffset(:, iWedge, iTrial) = currData - mean(currData, 'omitnan');
   end    
end

% Find max and min values 
% yMax = max(shiftDataOffset(800:end));
% yMin = min(shiftDataOffset(800:end));
yMax = max(shiftDataOffset(:), [], 'omitnan');
yMin = min(shiftDataOffset(:), [], 'omitnan');
range = max(abs([yMax, yMin]), [], 'omitnan') *  2.5;

% Create figure and plots
f = figure(11);clf;
f.Color = [1 1 1];
if ~isempty(figSize)
   f.Position(3:4) = figSize; 
end
for iPlot = 1:8
    ax = subaxis(1, nPlots, iPlot, 'mt', 0, 'ml', 0.05, 'mr', 0.03, 'mb', 0.08, 'sh', 0.05);
    hold on;
    currData = squeeze(shiftDataOffset(:, iPlot, :)); % --> [barPos, trial]
    currData = currData(:, ~[bl.usingOptoStim]);
    
    % Plot data
    plotX = -180:3.75:(180 - 3.75);
    
    % Separate data into distinct rows
    offsets = []; allPlotX = [];
    currData = fliplr(currData); % Flip so first trial is in the last column
    for iTrial = 1:size(currData, 2)
        currOffset = (range * (iTrial - 1));
        offsets(iTrial) = currOffset;
        currData(:, iTrial) = currData(:, iTrial) + currOffset;
        allPlotX(:, iTrial) = plotX;
        allPlotX(isnan(currData(:, iTrial)), iTrial) = nan;
%         plot([plotX(1), plotX(end)], [currOffset, currOffset], '--', 'color', 'b') % Plot zero lines
    end
    plot(allPlotX, currData, 'color', 'k', 'linewidth', 1.25);
    yL(1) = yMin * 1.25;
    yL(2) = range * (size(currData, 2));
    hold on; plot([0 0], yL, 'color', 'b', 'linewidth', 1)
    ylim(yL);
    
    xlabel('Bar position (deg)');
    if iPlot == 1
        ylabel('Trial', 'fontsize', 16);
    end
    ax.YTick = offsets;
    yTickLabel = size(shiftDataOffset, 3):-1:1;
    ax.YTickLabel = yTickLabel(~bl.usingOptoStim);
    
    % Indicate missing opto stim trials
    skippedTrials = 0;
    optoStimTrials = find([bl.usingOptoStim]);   
    for iTrial = 1:numel(optoStimTrials)
        offsetsRev = offsets(end:-1:1);
        plotOffset = offsetsRev(optoStimTrials(iTrial) - skippedTrials - 1) - (range / 2);
        skippedTrials = skippedTrials + 1;
        if bl.usingPanels(optoStimTrials(iTrial))
            lineColor = 'green';
        else
            lineColor = 'red';
        end
        plot([plotX(1), plotX(end)], [plotOffset, plotOffset], '-', 'color', lineColor, ...
                'linewidth', 1.5)
    end
    
end

% Add figure title
figTitleStr = {[bl.expID, '  -  Visual tuning of EB wedges (mean ', figTitleText, ')'], ...
        'Green line  =  trial with opto + visual stim', ...
        '  Red line  = trial with opto stim only'};
if omitMoveVols
    figTitleStr{1} = [figTitleStr{1}, '  -  excluding volumes within ', num2str(moveDistThresh), ...
            ' sec of movement'];
end
h = suptitle(figTitleStr);
h.FontSize = 14;
    
% Save figure
if saveFig
   saveDir = fullfile(analysisDir, bl.expID);
   save_figure(f, saveDir, saveFileName);
end

%% ===================================================================================================
%% Plot min and max values from the tuning curves
%===================================================================================================

saveFig = 1;

omitMoveVols = 1;

smWin = 3;

sourceData = bl.wedgeRawFlArr;
sourceData = bl.wedgeDffArr;
% sourceData = bl.wedgeZscoreArr;
sourceData = bl.wedgeExpDffArr;

figSize = [];
figSize = [400 925];

% Generate figure labels and save file name
if isequal(sourceData, bl.wedgeDffArr)
    figTitleText = 'dF/F';
    saveFileName = 'tuning_curve_amplitudes_dff';
elseif isequal(sourceData, bl.wedgeRawFlArr)
    figTitleText = 'Raw F';
    saveFileName = 'tuning_curve_amplitudes_rawF';
elseif isequal(sourceData, bl.wedgeZscoreArr)
    figTitleText = 'Z-scored dF/F';
    saveFileName = 'tuning_curve_amplitudes_zscored-dff';
elseif isequal(sourceData, bl.wedgeExpDffArr)
    figTitleText = 'full exp dF/F';
    saveFileName = 'tuning_curve_amplitudes_exp-dff';
else
    errordlg('Error: sourceData mismatch');
end

% Replace volumes when fly was moving with nan if necessary
if omitMoveVols
   moveDistThreshVols = round(moveDistThresh * bl.volumeRate);
   moveDistArr = permute(repmat(bl.moveDistVols, 1, 1, 8), [1 3 2]);
   sourceData(moveDistArr < moveDistThreshVols) = nan; 
   saveFileName = [saveFileName, '_no-movement'];
end

% Get mean panels pos data
panelsPosVols = [];
for iVol = 1:size(bl.wedgeDffArr, 1)
    [~, currVol] = min(abs(bl.panelsFrameTimes - bl.volTimes(iVol)), [], 'omitnan');
    panelsPosVols(iVol) = bl.panelsPosX(currVol);
end
tuningData = [];
for iPos = 1:numel(unique(bl.panelsPosX))
    tuningData(iPos, :, :) = ...
            mean(sourceData(panelsPosVols == (iPos - 1), :, :), 1, 'omitnan'); % --> [barPos, wedge, trial]    
end

% Smooth data, then find the max and min for each trial and wedge
tuningDataSm = repeat_smooth(tuningData, 10, 'smWin', smWin);
minVals = []; maxVals = [];
for iTrial = 1:size(tuningDataSm, 3)
    minVals(:, iTrial) = min(tuningDataSm(:, :, iTrial), [], 1, 'omitnan'); % --> [wedge, trial]
    maxVals(:, iTrial) = max(tuningDataSm(:, :, iTrial), [], 1, 'omitnan'); % --> [wedge, trial]
end
xTickLabel = 1:size(minVals, 2);

% Cut out opto stim trials
optoStimTrials = [bl.usingOptoStim];
postStimTrials = [0, optoStimTrials(1:end - 1)];
postStimTrials = postStimTrials(~optoStimTrials);
optoStimPanels = bl.usingPanels;
prevStimPanels = [0, optoStimPanels(1:end - 1)];
prevStimPanels = prevStimPanels(~optoStimTrials);
xTickLabel = xTickLabel(~optoStimTrials);
minVals = minVals(:, ~optoStimTrials);  % --> [wedge, trial]
maxVals = maxVals(:, ~optoStimTrials);  % --> [wedge, trial]
tuningAmp = maxVals - minVals;          % --> [wedge, trial]

% Plot change in min and max over time, omitting opto stim trials
f = figure(2);clf;
f.Color = [1 1 1];
if ~isempty(figSize)
    f.Position(2) = 50;
   f.Position(3:4) = figSize; 
end
globalMax = 0;
nPlots = size(sourceData, 2);
for iPlot = 1:nPlots
    ax = subaxis(nPlots, 1, iPlot, 'mt', 0.08, 'mb', 0.06, 'sv', 0.03, 'mr', 0.03, 'ml', 0.08);
    hold on;
%     plot(1:size(minVals, 2), minVals(iPlot, :), 'o', 'color', 'b')
%     plot(1:size(maxVals, 2), maxVals(iPlot, :), 'o', 'color', 'm')
    plot(1:size(tuningAmp, 2), tuningAmp(iPlot, :), 'o', 'color', 'k')
    stimTrials = find(postStimTrials);
    for iTrial = stimTrials
        if prevStimPanels(iTrial)
            lineColor = 'green';
        else
            lineColor = 'red';
        end
        yL = [0 ceil(max(tuningAmp(:)))];%ylim();
        plot([iTrial - 0.5, iTrial - 0.5], yL, '-', 'color', lineColor, ...
            'linewidth', 1.5)
    end
    if iPlot == nPlots
        xlabel('Trial number', 'fontsize', 13)
    else
        ax.XTickLabel = [];
    end
    xL = xlim;
    xlim([0, xL(2) + 1])
%     ylabel(num2str(iPlot))
end

for iAx = 1:numel(f.Children)
   if strcmp(f.Children(iAx).Tag, 'subaxis')
       f.Children(iAx).YLim = [0, 1.2 * max(tuningAmp(:))];
   end
end

% Plot title at top of figure
figTitleStr = {[bl.expID, ' - EB wedge visual tuning'], ...
        [figTitleText, '  (max - min)'], ... 
        'Green line  =  trial with opto + visual stim', ...
        '  Red line  = trial with opto stim only'};
if omitMoveVols
    figTitleStr{2} = [figTitleStr{2}, '  -  excl. move.'];
end
h = suptitle(figTitleStr);
h.FontSize = 12;

% Save figure
if saveFig
   saveDir = fullfile(analysisDir, bl.expID);
   save_figure(f, saveDir, saveFileName);
end

%% ===================================================================================================
%% Plot summary of tuning curve amplitudes
%===================================================================================================

saveFig = 1;

omitMoveVols = 1; 

smWin = 3;

sourceData = bl.wedgeRawFlArr;
sourceData = bl.wedgeDffArr;
% sourceData = bl.wedgeZscoreArr;
sourceData = bl.wedgeExpDffArr;


% Generate figure labels and save file name
if isequal(sourceData, bl.wedgeDffArr)
    figTitleText = 'dF/F';
    saveFileName = 'tuning_curve_amplitude_summary_dff';
elseif isequal(sourceData, bl.wedgeRawFlArr)
    figTitleText = 'Raw F';
    saveFileName = 'tuning_curve_amplitude_summary_rawF';
elseif isequal(sourceData, bl.wedgeZscoreArr)
    figTitleText = 'Z-scored dF/F';
    saveFileName = 'tuning_curve_amplitude_summary_zscored-dff';
elseif isequal(sourceData, bl.wedgeExpDffArr)
    figTitleText = 'full exp dF/F';
    saveFileName = 'tuning_curve_amplitude_summary_exp-dff';
else
    errordlg('Error: sourceData mismatch');
end


% Replace volumes when fly was moving with nan if necessary
if omitMoveVols
   moveDistThreshVols = round(moveDistThresh * bl.volumeRate);
   moveDistArr = permute(repmat(bl.moveDistVols, 1, 1, 8), [1 3 2]);
   sourceData(moveDistArr < moveDistThreshVols) = nan; 
   saveFileName = [saveFileName, '_no-movement'];
end

% Get mean panels pos data
panelsPosVols = [];
for iVol = 1:size(bl.wedgeDffArr, 1)
    [~, currVol] = min(abs(bl.panelsFrameTimes - bl.volTimes(iVol)), [], 'omitnan');
    panelsPosVols(iVol) = bl.panelsPosX(currVol);
end
tuningData = [];
for iPos = 1:numel(unique(bl.panelsPosX))
    tuningData(iPos, :, :) = ...
            mean(sourceData(panelsPosVols == (iPos - 1), :, :), 1, 'omitnan'); % --> [barPos, wedge, trial]    
end

% Get mean panels pos data
panelsPosVols = [];
for iVol = 1:size(bl.wedgeDffArr, 1)
    [~, currVol] = min(abs(bl.panelsFrameTimes - bl.volTimes(iVol)));
    panelsPosVols(iVol) = bl.panelsPosX(currVol);
end
tuningData = [];
for iPos = 1:numel(unique(bl.panelsPosX))
    tuningData(iPos, :, :) = ...
            mean(sourceData(panelsPosVols == (iPos - 1), :, :), 1, 'omitnan'); % --> [barPos, wedge, trial]    
end

% Smooth data, then find the max and min for each trial and wedge
tuningDataSm = repeat_smooth(tuningData, 10, 'smWin', smWin);
minVals = []; maxVals = [];
for iTrial = 1:size(tuningDataSm, 3)
    minVals(:, iTrial) = min(tuningDataSm(:, :, iTrial), [], 1, 'omitnan'); % --> [wedge, trial]
    maxVals(:, iTrial) = max(tuningDataSm(:, :, iTrial), [], 1, 'omitnan'); % --> [wedge, trial]
end
xTickLabel = 1:size(minVals, 2);

% Cut out opto stim trials
optoStimTrials = [bl.usingOptoStim];
postStimTrials = [0, optoStimTrials(1:end - 1)];
postStimTrials = postStimTrials(~optoStimTrials);
optoStimPanels = bl.usingPanels;
prevStimPanels = [0, optoStimPanels(1:end - 1)];
prevStimPanels = prevStimPanels(~optoStimTrials);
xTickLabel = xTickLabel(~optoStimTrials);
minVals = minVals(:, ~optoStimTrials);  % --> [wedge, trial]
maxVals = maxVals(:, ~optoStimTrials);  % --> [wedge, trial]
tuningAmp = maxVals - minVals;          % --> [wedge, trial]


% Group by experiment epoch
blockAmps = [];
blockStartTrials = [1, find(postStimTrials)];
for iBlock = 1:numel(blockStartTrials)
    startTrial = blockStartTrials(iBlock);
    if iBlock == numel(blockStartTrials)
        endTrial = size(tuningAmp, 2);
    else
        endTrial = blockStartTrials(iBlock + 1) - 1;
    end
    blockAmps(:, iBlock) = mean(tuningAmp(:, startTrial:endTrial), 2); % --> [wedge, block]
end

% Pull out the tuning curve amplitudes for trials before and after opto stims
blockAmps = [];
blockStartTrials = find(postStimTrials);
for iTrial = 1:numel(blockStartTrials)
   preStim = blockStartTrials(iTrial) - 1;
   postStim = blockStartTrials(iTrial);
   blockAmps(:, :, iTrial) = tuningAmp(:, [preStim, postStim]); % --> [wedge, trial, stim trial num]
end
blockAmps = permute(blockAmps, [2, 1 3]); % --> [trial, wedge, stim trial Num]

% Create figure
nStimTrials = size(blockAmps, 3);
f = figure(1);clf;
f.Color = [1 1 1];
f.Position = [f.Position(1:2), nStimTrials * 300, 450];
usingPanels = bl.usingPanels(logical(bl.usingOptoStim));
optoStimTrials = bl.trialNum(logical(bl.usingOptoStim));
for iTrial = 1:nStimTrials
    subaxis(1, nStimTrials, iTrial, 'mr', 0.04, 'ml', 72 / f.Position(3), 'mt', 0.15, 'mb', 0.11); hold on; box off
    plot(blockAmps(:, :, iTrial), 'o-')
    ax = gca;
    ax.XTick = [1 2];
    ax.XTickLabel = {'Before', 'After'};
    ax.FontSize = 12;
    xlim([0.75 2.25]);
    if usingPanels(iTrial)
        title(['Opto + bar (trial ', num2str(optoStimTrials(iTrial)), ')'], 'FontSize', 12)
    else
        title(['Opto only (trial ', num2str(optoStimTrials(iTrial)), ')'], 'FontSize', 12)
    end
    
    % Plot mean amplitude for each group
    plot([mean(blockAmps(1, :, iTrial)), mean(blockAmps(2, :, iTrial))], ...
            'o-', 'Color', 'k', 'linewidth', 5)
    
    % Track Y limits of each axis
    if iTrial == 1
       figYLims = ylim();
       ylabel('Max - min tuning curve dF/F', 'fontsize', 13) 
    else
       currYLims = ylim();
       figYLims = [min([figYLims(1), currYLims(1)]), max([figYLims(2), currYLims(2)])];
    end
end
% Make each plot use the same Y limits
for iAx = 1:numel(f.Children)
    try
        f.Children(iAx).YLim = figYLims;
    catch
    end
end

figTitleStr = ([bl.expID, '  -   ', figTitleText]);
if omitMoveVols
    figTitleStr = [figTitleStr, '  -  excl. vol. within ', num2str(moveDistThresh), ...
            ' sec of movement'];
end
suptitle(figTitleStr)


% Save figure
if saveFig
   saveDir = fullfile(analysisDir, bl.expID);
   save_figure(f, saveDir, saveFileName);
end


