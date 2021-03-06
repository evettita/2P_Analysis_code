function make_behavior_vids(vidDataDir, vidSaveDir, sid)
try
    
    % Run full behavior vid processing workflow
    addpath('/home/mjm60/HelperFunctions') % if running on O2 cluster
    write_to_log('Starting behavior vid processing...', mfilename)
    
    % Initialize cluster communication
    c = parcluster;
   
    write_to_log('Cluster communication opened...', mfilename)
    
    % Extract expDate from directory path
    expDate = regexp(vidDataDir, '(?<=/)20.*(?=/)', 'match');
    expDate = expDate{:};
    
    %-----------------------------------------------------------------------------------------------
    
    % Identify block vids
    if ~exist(fullfile(vidDataDir, ['sid_', num2str(sid)]), 'dir')
        blockDataDir = vidDataDir;
        write_to_log('Getting raw vids from vid data directory', mfilename);
    else
        write_to_log('Getting raw vids from sid-specific subdirectory', mfilename);
        blockDataDir = fullfile(vidDataDir, ['sid_', num2str(sid)]); % For expts with multiple sids
    end
    blockVids = dir(fullfile(blockDataDir, 'fc2_save*.avi'));
    blockVids = blockVids(~contains({blockVids.name}, 'tid')); % In case there are already single trial vids
    nBlocks = numel(blockVids);
    write_to_log(['nBlocks = ', num2str(nBlocks)],mfilename);
    
    % Remake block vids so that they can be read correctly by Matlab  
    vidCheckComplete = 0;
    while ~vidCheckComplete
        
        memGB = 2;
        timeLimitMin = 10;
        queueName = 'short';
        jobName = [expDate, '_sid_', num2str(sid), '_remake_block_vids'];
        remakeJobArr = [];
        c = set_job_params(c, queueName, timeLimitMin, memGB, jobName);

        % Check whether any any of the block vid files are missing
        write_to_log('Checking for missing block vid files...', mfilename);
        missingBlocks = [];
        for iBlock = 1:nBlocks
            if ~exist(fullfile(vidDataDir, ['block_vid_sid_', num2str(sid), '_bid_', ...
                        pad(num2str(iBlock - 1), 3, 'left', '0'), '.avi']), 'file')
                missingBlocks(end + 1) = iBlock - 1;
            end
        end
        if ~isempty(missingBlocks)
            write_to_log(['Missing vids for the following blocks: ', num2str(missingBlocks)], ... 
                    mfilename);           
            
            for iBlock = 1:numel(missingBlocks)
                currBlock = missingBlocks(iBlock);
                inputArgs = {vidDataDir, blockVids(currBlock + 1).name, sid, currBlock}
                remakeJobArr{iBlock} = c.batch(@remake_block_vid, 0, inputArgs);
            end
            
        else
            write_to_log('All block vids have been remade', mfilename);
            vidCheckComplete = 1;
        end
            % Pause execution until all jobs are done
        remakeJobArr = wait_for_jobs(remakeJobArr);
    end
    
    % Identify new block vids
    blockVids = dir(fullfile(vidDataDir, ['block_vid_sid_', num2str(sid), '_bid_*.avi']));
    blockVids = blockVids(~contains({blockVids.name}, 'tid')); % In case there are already single trial vids
    nBlocks = numel(blockVids);
    
    % Separate block videos into invididual trials
    write_to_log('Splitting block videos into individual trials...', mfilename)
    memGB = 4;
    timeLimitMin = 120;
    queueName = 'short';
    jobName = [expDate, '_sid_', num2str(sid), '_split_block_vids'];
    splitJobArr = [];
    for iBlock = 1:nBlocks
        
        currBid = regexp(blockVids(iBlock).name, '(?<=bid_).*(?=.avi)', 'match');
        write_to_log(['Block ID = ', currBid{:}], mfilename);
        
        % Check whether this block has already been separated into trials
        if isempty(dir(fullfile(vidDataDir, ['*sid_', num2str(sid), '*bid_', currBid{:}, ...
                '*tid*'])))
            
            write_to_log([fullfile(vidDataDir, ['*sid_', num2str(sid), '*bid_', currBid{:}, ...
                '*tid*']), ' does not exist...splitting frames now'], mfilename)
            
            % Check whether block is closed-loop (and therefore all one trial)
            mdFileStr = ['metadata*sid_', num2str(sid), '_bid_', ...
                    num2str(str2double(currBid{:})), '.mat'];
            mdFileName = dir(fullfile(vidDataDir, mdFileStr));
            write_to_log(['mdFileName: ', mdFileName.name], mfilename);
            mData = load(fullfile(vidDataDir, mdFileName.name));
            stimType = mData.metaData.stimTypes{1};
            write_to_log(['Stim type: ', stimType], mfilename);
            
            % Start job
            c = set_job_params(c, queueName, timeLimitMin, memGB, jobName);
            if regexp(stimType, 'Closed_Loop')
                inputArgs = {vidDataDir, blockVids(iBlock).name, ...
                    'closedLoop', 1}
            else
                inputArgs = {vidDataDir, blockVids(iBlock).name}
            end
            splitJobArr{end + 1} = c.batch(@split_block_vids, 0, inputArgs);
        else
            write_to_log(['Skipping block ', currBid{:}, ...
                ' because single-trial videos ...already exist'], mfilename);
        end%if
    end%for
    splitJobArr = wait_for_jobs(splitJobArr);
    
    
    %-----------------------------------------------------------------------------------------------
    
    
    % Update vid files to reflect any changes from imaging data cleanup, then move to output dir
    vid_dir_cleanup(vidDataDir, sid);
    
    
    %-----------------------------------------------------------------------------------------------
    
    % Get list of the raw video data directories and trial IDs
    trialVids = dir(fullfile(vidDataDir, '*sid*tid*.avi'));
    tid = 0; trialVidNames = []; tidList = [];
    for i = 1:numel(trialVids)
        currSid = str2double(regexp(trialVids(i).name, '(?<=sid_).*(?=_bid)', 'match'));
        if currSid == sid
            tid = tid + 1;
            trialVidNames{end+1} = trialVids(i).name;
            tidList(end+1) = tid;
        end
    end
    disp(tidList);
    write_to_log(['numel(tidList) = ', num2str(numel(tidList))], mfilename);
    
    write_to_log('Raw trial vids identified...', mfilename)
    
    %-----------------------------------------------------------------------------------------------
    
    
    % Rename videos and copy them to the output directory
    for iTrial = 1:numel(trialVidNames)
        disp(iTrial)
        trialStr = ['sid_', num2str(sid), '_tid_', pad(num2str(tidList(iTrial)), 3, 'left', '0'), ...
            '.avi'];
        sourceFileName = fullfile(vidDataDir, trialVidNames{iTrial});
        destFileName = fullfile(vidSaveDir, trialStr);
        copyfile(sourceFileName, destFileName);
    end
    
    %-----------------------------------------------------------------------------------------------
    
    
    % Count number of frames in the individual trial videos
    allVidFrameCounts = count_vid_frames(vidSaveDir, sid);
    maxFrames = max(allVidFrameCounts);
    
    disp(allVidFrameCounts)
    disp(maxFrames)
    
    write_to_log(['Video frames counted, maxFrames = ', num2str(maxFrames), '...'], mfilename);
    
    
    %-----------------------------------------------------------------------------------------------
    
    
    % Start job to concatenate processed trial behavior vids
    memGB = 8;
    timeLimitMin = 120;
    queueName = 'short';
    jobName = [expDate, '_sid_', num2str(sid), '_concatRawVids'];
    c = set_job_params(c, queueName, timeLimitMin, memGB, jobName);
    fileStr = ['*sid_', num2str(sid), '_tid*.avi'];
    outputFileName = ['sid_', num2str(sid), '_AllTrials'];
    inputArgs = {vidSaveDir, fileStr, 'OutputFile', outputFileName}
    concatVidJob = c.batch(@concat_vids, 0, inputArgs);
    
    
    %-----------------------------------------------------------------------------------------------
    
    
    % % Start jobs to calculate optic flow for all trials
    
    flowCheckComplete = 0;
    while ~flowCheckComplete
        
        c = set_job_params(c, queueName, timeLimitMin, memGB, jobName);
        memGB = 1;
        b = 0.015;
        % if maxFrames <= 2000
        %     b = 0.08;
        % else
        %     b = 0.02;
        % end
        timeLimitMin = ceil(b * maxFrames);
        queueName = 'short';
        jobName = [expDate, '_sid_', num2str(sid), '_opticFlowCalc'];
        c = set_job_params(c, queueName, timeLimitMin, memGB, jobName);
        roiFilePath = fullfile(vidDataDir, 'Behavior_Vid_ROI_Data.mat');
        flowVidDir = fullfile(vidSaveDir, 'opticFlowVids');
        flowJobArr = [];
        
        % Check whether any any of the flow vid data files are missing
        write_to_log('Checking for missing optic flow data...', mfilename);
        missingTids = [];
        for iTrial = 1:numel(trialVidNames)
            if ~exist(fullfile(flowVidDir, ['sid_', num2str(sid), '_tid_', ...
                        pad(num2str(tidList(iTrial)), 3, 'left', '0'), '_optic_flow_data.mat']), ...
                        'file')
                missingTids(end + 1) = tidList(iTrial);
            end
        end
        if ~isempty(missingTids)
            write_to_log(['Missing flow data for the following trials: ', num2str(missingTids)], ...
                mfilename);
            
            for iTrial = 1:numel(missingTids)
                disp([vidSaveDir, ' ', num2str(sid), ' ', num2str(missingTids(iTrial)), ' ', ...
                    roiFilePath, ' ', flowVidDir])
%             %------------------------------------------
%             % Create log file for debugging
%                 myFile = fopen(fullfile('/home/mjm60/flowlogfiles', ...
%                         ['sid_', num2str(sid), '_tid_', pad(num2str(tid), 3, 'left', '0'), ...
%                         '_log.txt']), 'a');
%                 fprintf(myFile, [datestr(datetime), ' Log file created', '\r\n']);
%                 fclose(myFile);
%             %------------------------------------------
                inputArgs = {vidSaveDir, sid, missingTids(iTrial), roiFilePath, 'OutputDir', ...
                    flowVidDir};
                flowJobArr{iTrial} = c.batch(@single_trial_optic_flow_calc, 0, inputArgs);
            end
            
        else
            write_to_log('All optic flow data accounted for', mfilename);
            flowCheckComplete = 1;
        end
        % Pause execution until all jobs are done
        flowJobArr = wait_for_jobs(flowJobArr);
    end
    
    % Normalize optic flow data across all trials
    normalize_optic_flow(flowVidDir, sid, 'OutputDir', vidSaveDir);
    
    write_to_log('Flow data normalized...', mfilename)
    
catch ME
    write_to_log(getReport(ME), mfilename);
end%try
end%function

%===================================================================================================
