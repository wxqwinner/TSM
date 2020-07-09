function [ y ] = uTVS_batch( x, fs, TSM, filename )
%[ y ] = muTVS( x, fs, TSM )
%muTVS proposed by Sharma et al., Mel-Scale Sub-band Modelling for
%Perceptually Improved Time-Scale Modification of Speech Audio Signals,
%2017
%   x is the input signal
%   fs is the sampling frequency
%   TSM is the TSM ratio 0.5 = 50%, 1 = 100% and 2.0 = 200% speed
%Printing to the screen is done to allow user to see that processing is
%taking place.  This is a slow method of processing.

% Tim Roberts - Griffith University 2018

%Generate Instantaneous Amplitude (IA) and Instantaneous Phase (IP) without
%the use for fft, which assumes quasi-stationarity

%Initial variables
K = 2*floor(fs/1000);   %32 for fs=16kHz
N = 2^nextpow2(fs/8);   %2048 for fs=16kHz
S = N/4;

oversample = 6;
%% --------------------------Analysis------------------------------
%This section splits the input signal into K band passed signals
disp('Analysis');
%Oversample
xr = resample(x,oversample,1);
fo = fs*oversample;
%Create window (Hann)
w = 0.5*(1 - cos(2*pi*(0:N-1)'/(N-1)));
%Frame the input
xw = buffer(xr, N, N-S);
%Window the frames
xw = xw.*repmat(w,1,size(xw,2));
%Convert to frequency domain
XW = fft(xw,N);
%Generate Filterbanks
disp('    Generate Filterbanks');
H = [zeros(K,1) , msf_filterbank(K,fo,0,fs/2,N)];
H(isnan(H)) = 0; %If N is too small, some values become NaN.
%Take the first half of the fft
XW_crop = XW(1:N/2+1,:);
%Prepare framed filterbank output
XWF = zeros(size(XW_crop,1),K,size(XW_crop,2));
%Mulitply through with the filterbanks.
disp('    Multiply filterbanks through signal');
for k = 1:K
    for f = 1:size(XW,2)
        XWF(:,:,f) = repmat(XW_crop(:,f),[1,K]).*H';
    end
end
%Reconstruct second half of the signal
XWF_recon = real(ifft([XWF;conj(XWF(end-1:-1:2,:,:))]));
%Prepare filterbank channels
xwf = zeros(size(XWF_recon,3)*S+1.75*N,K); %Need to make this longer.  Janky solution for now.
%Create the output window
wo = repmat(w,1,size(XWF_recon,2));
%Overlap add the signal back together
disp('    Overlap Add the signal back together');
for f = 1:size(XWF,3)
    xwf((f-1)*S+1:(f-1)*S+N,:) = xwf((f-1)*S+1:(f-1)*S+N,:)+XWF_recon(:,:,f).*wo;
end

%At this point, xwf_jl is a K channel signal version of the original x
%input signal

%% --------------------------Modification------------------------------
%For each bank:
disp('Modification')
%Hilbert Transform to extract IA and IP
disp('    Hilbert');
xak_h = hilbert(xwf);
%Calculate the Instantaneous Amplitude and Phase
ak = abs(xak_h);
phik = unwrap(angle(xak_h));

for t = 1:length(TSM)
    tsm = TSM(t);
    a = 1/tsm;
    
    %Time scale through interpolation
    ak_hat = zeros(ceil(length(ak)*a),K);
    phik_hat = zeros(ceil(length(phik)*a),K);
    old_points = (1:length(ak));
    new_points = round(a*(old_points-1))+1; %-1 to 0 index old points, +1 to 1 index new-points
    %Assign to the new time scale
    disp('    Assign new time scale');
    ak_hat(new_points,:) = ak(old_points,:);
    phik_hat(new_points,:) = a*phik(old_points,:);
    %Interpolate missing values
    disp('    Interpolate each filterband: ')
    ak_hat_i = zeros(length(ak_hat),K);
    phik_hat_i = zeros(length(phik_hat),K);
    for k = 1:K
        ak_hat_i(:,k) = linear_interp_zeros_subj(ak_hat(:,k), tsm);
        phik_hat_i(:,k) = linear_interp_zeros_subj(phik_hat(:,k), tsm);
        fprintf('    Band %d complete\n',k);
    end
    %Multiply output IA and IP
    x_hat = ak_hat_i.*cos(phik_hat_i);
    %% --------------------------Synthesis------------------------------
    disp('Synthesis')
    %Combine the filterbank audio signals
    x_hat_sum = sum(x_hat,2);
    %Resampling the output
    y = resample(x_hat_sum,1,oversample);
    %Normalise the output
    y=y/max(abs(y));
    
    f = [filename(1:end-4) sprintf('_muTVS_%g',tsm*100) '.wav'];
    audiowrite(f,y,fs);
    
end

disp('File Processing Complete');
end
