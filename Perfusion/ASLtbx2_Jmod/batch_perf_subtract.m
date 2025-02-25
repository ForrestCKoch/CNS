% Toolbox for batch processing ASL perfusion based fMRI data.
% All rights reserved.
% Ze Wang @ TRC, CFN, Upenn 2004
%
% Batch calculation for the perfusion signals.

for sb = 1:PAR.nsubs % for each subject

    sprintf('Calculate perfusion and CBF signals for subject #%g ... %g subjects left...\n',sb,length(PAR.subjects)-sb)
    for c=1:PAR.ncond

        P =  spm_select('ExtFPList', PAR.condirs{sb,c}, ['^sASLflt.*\.nii'], 1:1000 );
       
        maskimg=spm_select('FPList', PAR.condirs{sb,c}, ['^brainmask\.nii']);
       
	    M0img =  spm_select('FPList', PAR.condirs{sb,c}, ['^srM0.*\.nii'] );
        
          
        %asl_perf_subtract(Filename,FirstimageType, SubtractionType,...
        %   SubtractionOrder,Flag,
        %Timeshift,AslType,labeff,MagType,
        %   Labeltime,Delaytime,Slicetime,TE, M0img,M0seg,maskimg)
        asl_perf_subtract(P, PAR.FirstimageType, PAR.SubtractionType, ...
            PAR.SubtractionOrder,   PAR.Flags,...
            PAR.TimeShift,     PAR.ASLType,      PAR.Labeff, PAR.MagType,...
            PAR.Labeltime,     PAR.Delaytime,    PAR.slicetime, PAR.TE,   M0img, [], maskimg);
        
        fprintf('\n%40s%30s','',' ');
    end
end

