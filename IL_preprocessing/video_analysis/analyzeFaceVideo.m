function [pupil, whisk, vid_start_idx] = analyzeFaceVideo(vid_dir, session, num_frames)
% analyze video of a mouse's face to extract pupil and whisking dynamics
%
% created by IL 7/18/18
% modified to accomodate new set-up in May 2019
%
%
% returns:
%       pupil     = vector, normalized pupil diameter for each video frame, 
%                   where 1 is most dilated and 0 is most constricted
%       whisk     = vector, normalized motion energy within whisker pad 
%                   ROI, where 1 is most motion, 0 is least motion
%       vid_start = time of first frame in 30s test video


% set up directories for retrieving and saving data
vid = VideoReader([vid_dir, session, '.mp4']);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Process relevant frames
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
disp('Getting video params...')
pupil = nan(num_frames,1);
whisk = nan(num_frames,1);

% start index for test video, can adjust
vid_start_idx = 18000;

tic
ii = 0;  % python is zero-indexed...this saves trouble later
for i = 1:num_frames
  frame = readFrame(vid);

  % using the first VR frame, set the ROIs for pupil and whisk
  if i == 1
    frame = rgb2gray(frame);

    % make fig
    h = figure();
    ax = axes('Parent', h);
    imshow(frame, 'Parent', ax);
    title(ax, sprintf('Frame #%d', 1));
    set(gcf,'Units','normalized')
    ax.Position = [0,0,1,1];

    % draw pupil ROI, corners at eyelids
    disp('Ready to draw pupil ROI? (press any key to continue)')
    pause
    [pupil_roi, roi_p] = makeROI(frame, h);
    disp('Ready to identify pupil? (press any key to continue)')
    pause
    [pupil_val,~] = makeROI(frame, h);
    thresh = mean(mean(pupil_val));
    pupil_roi(pupil_roi > thresh) = 1; % threshold
    pupil_roi(pupil_roi < thresh) = 0;
    figure()
    imshow(pupil_roi)
    % calculate avg pixel intensity within pupil ROI 
    pupil(i) = mean(mean(pupil_roi));

    % draw whisker ROI around whisker ends
    disp('Ready to draw whisker ROI? (press any key to continue)')
    pause
    [whisk_roi, roi_w] = makeROI(frame, h);
    figure()
    imshow(whisk_roi)    
    % save whisk ROI to calculate motion
    last_whisk = whisk_roi;
    
    disp('Processing video data (this may take awhile)...')
    
  elseif any(frame_idx == i) % process all relevant frames
      frame = rgb2gray(frame);
      
      % calculate avg pixel intensity within pupil ROI
      [pupil_roi,~] = makeROI(frame, h, roi_p);
      pupil_roi(pupil_roi > thresh) = 1; % threshold
      pupil_roi(pupil_roi < thresh) = 0;
      pupil(i) = mean(mean(pupil_roi));
      
      % calculate avg motion energy within whisk ROI
      [whisk_roi,~] = makeROI(frame, h, roi_w);
      whisk(i) = mean(mean(abs(whisk_roi - last_whisk)));
      last_whisk = whisk_roi;
  end
  % at 15 mins, save 30 seconds of frames to check video
  if (i >= frame_idx(vid_start_idx)) && (i < frame_idx(vid_start_idx + 600))
      filename = ['frame_' sprintf('%03d',ii) '.jpg'];
      fullname = [vid_dir filename];
      imwrite(frame,fullname);
      ii = ii+1;
  end
end
time = toc;
disp('min to extract pupil and whisk data:')
disp(time/60)


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Clean up and normalize
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
whisk = [whisk(1); whisk(~isnan(whisk))];

% z-score to remove extreme outliers
z_pupil = pupil - mean(pupil);
z_pupil = z_pupil/std(z_pupil);
pdx = abs(z_pupil) > 2;
pupil(pdx) = NaN;
% interpolate and smooth
pupil(isnan(pupil)) = interp1(find(~isnan(pupil)), pupil(~isnan(pupil)), find(isnan(pupil)), 'pchip');
pupil = gauss_smoothing(pupil,10); % can adjust this value to smooth more or less

% throw out extreme outliers
z_whisk = whisk - mean(whisk);
z_whisk = z_whisk/std(z_whisk);
wdx = abs(z_whisk) > 2;
whisk(wdx) = NaN;
% interpolate and smooth
whisk(isnan(whisk)) = interp1(find(~isnan(whisk)), whisk(~isnan(whisk)), find(isnan(whisk)), 'pchip');
whisk = gauss_smoothing(whisk,10); % can adjust this value to smooth more or less

% normalize
pupil = pupil - min(pupil);
pupil = pupil / max(pupil);
pupil = 1 - pupil; % flip so dilating is bigger
whisk = whisk - min(whisk);
whisk = whisk / max(whisk);

assert(numel(pupil) == num_frames & numel(whisk) == num_frames

end
