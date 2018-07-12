function [ y ] = WSOLA( x, N, TSM )
%[ y ] = WSOLA( x, N, TSM )
%   x - Input audio waveform
%   N - Frame length
%   TSM - Time-Scale parameter. 0.5=50%, 1 = 100%, 2 = 200% playback speed
%   Proposed by Verhelst and Roelands, An Overlap-Add Technique Based on
%   Waveform Similarity (WSOLA) for High Quality Time-Scale Modification of
%   Speech, 1993.

% Tim Roberts - Griffith University 2018
num_chan = size(x,2);

alpha = 1/TSM;
w = 0.5*(1 - cos(2*pi*(0:N-1)'/(N-1))); %hanning window
Ss = N/4;               %Synthesis shift
tol = N/4;              %Tolerance
Sa = round(Ss/alpha);   %Analysis shift
y = zeros(ceil(length(x)*alpha),num_chan); %1.1 is to allow for non exct time scaling
for c = 1:size(x,2)
    xc = x(:,c);
    yc = zeros(ceil(length(x)*alpha),1); %1.1 is to allow for non exct time scaling
    
    low_lim = N/4;            %Cross correlation low limit
    high_lim = N/8;           %Cross correlation high limit
    
    yc(1:N,:) = xc(1:N,:).*w;     %Copy the first frame.
    nat_prog = xc(Ss+1:Ss+N,:); %Set the first natural progression
    M = 2;                  %Frame number
    
    while M*Sa<length(xc)-(tol+2*N)
        %Create the new input grain
        in_grain_low = M*Sa+1-tol;
        in_grain_high = M*Sa+N+tol;
        if (in_grain_low < 1)
            %If the tolerance of the grain is 'before' the file
            in_grain_low = 1;
        end
        if (in_grain_high > length(xc))
            %If the tolerance of the grain is 'after' the file
            in_grain_high = length(xc);
        end
        %Extract the grain
        in_grain = xc(in_grain_low:in_grain_high);
        %Ensure the length of the input grain region
        if(length(in_grain)~=(N+2*tol))
            if(in_grain_low == 1)
                %Short at the start
                in_grain = [zeros(N+2*tol-length(in_grain),1);in_grain];
            else
                %Short at the end
                in_grain = [in_grain ; zeros(N+2*tol-length(in_grain),1)];
            end
        end
        
        %Compute Correlation between input grain and the natural progression
        %from the previous overlapped grain
        [x_lag,y_lag] = maxcrosscorrlag(in_grain, nat_prog, low_lim, high_lim);
        delta = y_lag-tol;
        %Create the new adjusted grain
        new_grain_low = M*Sa+1+delta;
        new_grain_high = M*Sa+N+delta;
        if (new_grain_low < 1)
            new_grain_low = 1;
        end
        if (new_grain_high > length(xc))
            new_grain_high = length(xc);
        end
        new_grain = xc(new_grain_low:new_grain_high);
        %Ensure the grain is N in length
        if(length(new_grain)~=N)
            %Only padding at end for OLA
            new_grain = [new_grain ; zeros(N-length(new_grain),1)];
        end
        %Apply window to the grain
        new_grain = new_grain.*w;
        %Overlap add
        yc(M*Ss+1:M*Ss+N,:) = yc(M*Ss+1:M*Ss+N,:)+new_grain;
        %Next natural progression
        nat_prog = xc(new_grain_low+Ss:new_grain_high+Ss,:);
        %Increment frame number
        M = M+1;
    end
    y(:,c) = yc;
end
y = y/max(max(abs(y)));
end

