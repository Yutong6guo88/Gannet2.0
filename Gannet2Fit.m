function [MRS_struct] = Gannet2Fit(MRS_struct)
%
% MRS_struct = structure with data loaded from MRSLoadPfiles
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Gannet 2.0 version of Gannet Fit - analysis tool for GABA-edited MRS.
% Need some new sections like
%   1. GABA Fit
%   2. Water Fit
%   3. Cr Fit
%%%%%%%%%%%%%%%%%%%%%%%%%%%%

FIT_LSQCURV = 0;
FIT_NLINFIT = 1;
fit_method = FIT_NLINFIT; %FIT_NLINFIT;
waterfit_method = FIT_NLINFIT;
GABAData=MRS_struct.spec.diff;
freq=MRS_struct.freq;
if strcmp(MRS_struct.Reference_compound,'H2O')
    WaterData=MRS_struct.spec.water;
end
MRS_struct.versionfit = '2 131016';
disp(['GABA Fit Version is ' MRS_struct.versionfit ]);
fitwater=1;
numscans=size(GABAData);
numscans=numscans(1);

%110624
epsdirname = [ './MRSfit_' datestr(clock,'yymmdd') ];


for ii=1:numscans
    MRS_struct.gabafile{ii};
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 
    % 1.  GABA Fit 
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%    
    % ...from GaussModel;
    % x(1) = gaussian amplitude
    % x(2) = 1/(2*sigma^2)
    % x(3) = centre freq of peak
    % x(4) = amplitude of linear baseline
    % x(5) = constant amplitude offset

    %Hard code it to fit from 2.79 ppm to 3.55 ppm
    z=abs(MRS_struct.freq-3.55);
    lowerbound=find(min(z)==z);
    z=abs(MRS_struct.freq-2.79);%2.75
    upperbound=find(min(z)==z);
    freqbounds=lowerbound:upperbound;
    plotbounds=(lowerbound-150):(upperbound+150);
    maxinGABA=max(real(GABAData(MRS_struct.ii,freqbounds)));
    % smarter estimation of baseline params, Krish's idea (taken from Johns
    % code; NAP 121211
    grad_points = (real(GABAData(ii,upperbound)) - real(GABAData(ii,lowerbound))) ./ ...
        (upperbound - lowerbound); %in points
    LinearInit = grad_points ./ (MRS_struct.freq(1) - MRS_struct.freq(2)); %in ppm
    constInit = (real(GABAData(ii,upperbound)) + real(GABAData(ii,lowerbound))) ./2;
    xval = [ 1:(upperbound-lowerbound+1) ];
    linearmodel = grad_points .* xval + GABAData(ii,lowerbound);
    %End copy code
    resnorm=zeros([numscans size(freqbounds,2)]);
    GaussModelInit = [maxinGABA -90 3.026 -LinearInit constInit]; %default in 131016
    lb = [0 -200 2.87 -40*maxinGABA -2000*maxinGABA]; %NP; our bounds are 0.03 less due to creatine shift
    ub = [4000*maxinGABA -40 3.12 40*maxinGABA 1000*maxinGABA];
    options = optimset('lsqcurvefit');
    options = optimset(options,'Display','off','TolFun',1e-10,'Tolx',1e-10,'MaxIter',1e5);
    nlinopts = statset('nlinfit');
    nlinopts = statset(nlinopts, 'MaxIter', 1e5);
     ii
    %Fitting to a Gaussian model happens here
     [GaussModelParam(ii,:),resnorm,residg] = lsqcurvefit(@(xdummy,ydummy) GaussModel_area(xdummy,ydummy), ...
        GaussModelInit, freq(freqbounds),real(GABAData(ii,freqbounds)), ...
        lb,ub,options);
        residg = -residg;
    if(fit_method == FIT_NLINFIT)
        GaussModelInit = GaussModelParam(ii,:);
        % 1111013 restart the optimisation, to ensure convergence
        for fit_iter = 1:100
            [GaussModelParam(ii,:), residg, J, COVB, MSE] = nlinfit(freq(freqbounds), real(GABAData(ii,freqbounds)), ... % J, COBV, MSE edited in
                @(xdummy,ydummy) GaussModel_area(xdummy,ydummy), ...
                GaussModelInit, ...
                nlinopts);
            MRS_struct.fitparams_iter(fit_iter,:,ii) = GaussModelParam(ii,:);
            GaussModelInit = GaussModelParam(ii,:);
            ci = nlparci(GaussModelParam(ii,:), residg,'covar',COVB); %copied over
        end
    end
    GABAheight = GaussModelParam(ii,1);
    % FitSTD reports the standard deviation of the residuals / gaba HEIGHT
    MRS_struct.GABAFitError(ii)  =  100*std(residg)/GABAheight;
    % This sets GabaArea as the area under the curve.
    MRS_struct.gabaArea(ii)=GaussModelParam(ii,1)./sqrt(-GaussModelParam(ii,2))*sqrt(pi);
    sigma = ( 1 / (2 * (abs(GaussModelParam(ii,2)))) ).^(1/2);
    MRS_struct.GABAFWHM(ii) =  abs( (2* MRS_struct.LarmorFreq) * sigma);
    MRS_struct.GABAModelFit(ii,:)=GaussModelParam(ii,:);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%   1A. Start up the output figure
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 
    fignum = 102;
    if(ishandle(fignum))
        close(fignum)
    end
    h=figure(fignum);
    set(h, 'Position', [100, 100, 1000, 707]);
    set(h,'Color',[1 1 1]);
    figTitle = ['GannetFit Output'];
    set(gcf,'Name',figTitle,'Tag',figTitle, 'NumberTitle','off');
    % GABA plot
    ha=subplot(2, 2, 1)
    % find peak of GABA plot... plot residuals above this...
    gabamin = min(real(GABAData(ii,plotbounds)));
    gabamax = max(real(GABAData(ii,plotbounds)));
    resmax = max(residg);
    residg = residg + gabamin - resmax;
    plot(freq(freqbounds),GaussModel_area(GaussModelParam(ii,:),freq(freqbounds)),'r',...
        freq(plotbounds),real(GABAData(ii,plotbounds)), 'b', ...
        freq(freqbounds),residg,'k');
    legendtxt = regexprep(MRS_struct.gabafile{ii}, '_','-');
    title(legendtxt);
    set(gca,'XDir','reverse');
    set(gca,'XLim',[2.6 3.6]);
    %%%%From here on is cosmetic - adding labels (and deciding where to).
    hgaba=text(3,gabamax/4,'GABA');
    set(hgaba,'horizontalAlignment', 'center');
    %determine values of GABA tail (below 2.8 ppm.
    z=abs(MRS_struct.freq-2.79);%2.75
    upperbound=find(min(z)==z);
    tailtop=max(real(GABAData(ii,upperbound:(upperbound+150))));
    tailbottom=min(real(GABAData(ii,upperbound:(upperbound+150))));
    hgabares=text(2.8,min(residg),'residual');
    set(hgabares,'horizontalAlignment', 'left');
    text(2.8,tailtop+gabamax/20,'data','Color',[0 0 1]);
    text(2.8,tailbottom-gabamax/20,'model','Color',[1 0 0]);
    set(gca,'YTick',[]);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 
% 2.  Water Fit 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    if strcmp(MRS_struct.Reference_compound,'H2O')
        T1=20;
        %estimate height and baseline from data
        maxinWater=max(real(WaterData(:)));
        waterbase = mean(real(WaterData(1:500))); % avg

        %Philips data do not phase well based on first point, so do a preliminary
        %fit, then adjust phase of WaterData accordingly     
        
        if(strcmpi(MRS_struct.vendor,'Philips'))
            %Run preliminary Fit of data
            LGModelInit = [maxinWater 20 4.7 0.0 waterbase -50 ]; %works

            lblg = [0.01*maxinWater 1 4.6 0 0 -50 ];
            ublg = [40*maxinWater 100 4.8 0.000001 1 0 ];
            %Fit from 5.6 ppm to 3.8 ppm RE 110826
            z=abs(MRS_struct.freq-5.6);
            waterlow=find(min(z)==z);
            z=abs(MRS_struct.freq-3.8);
            waterhigh=find(min(z)==z);
            freqbounds=waterlow:waterhigh;
            % Do the water fit (Lorentz-Gauss)
            nlinopts = statset('nlinfit');
            nlinopts = statset(nlinopts, 'MaxIter', 1e5);
            [LGModelParam(ii,:),residw] = nlinfit(freq(freqbounds), real(WaterData(ii,freqbounds)),...
                @(xdummy,ydummy)	LorentzGaussModel(xdummy,ydummy),...
                LGModelInit, nlinopts);
            residw = -residw;
            %Then use this for phasing
            error=zeros([120 1]);
            for jj=1:120
                Data=WaterData(ii,freqbounds)*exp(1i*pi/180*jj*3);
                Model=LorentzGaussModel(LGModelParam(ii,:),freq(freqbounds));
                error(jj)=sum((real(Data)-Model).^2);
            end
            [number index]=min(error);
            WaterData=WaterData*exp(1i*pi/180*index*3);
        end
    % x(1) = Amplitude of (scaled) Lorentzian
    % x(2) = 1 / hwhm of Lorentzian (hwhm = half width at half max)
    % x(3) = centre freq of Lorentzian
    % x(4) = linear baseline amplitude
    % x(5) = constant baseline amplitude
    % x(6) =  -1 / 2 * sigma^2  of gaussian
    LGModelInit = [maxinWater 20 4.7 0 waterbase -50 ]; %works
        lblg = [0.01*maxinWater 1 4.6 0 0 -50 ];
        ublg = [40*maxinWater 100 4.8 0.000001 1 0 ];
        %Fit from 5.6 ppm to 3.8 ppm RE 110826
        z=abs(MRS_struct.freq-5.6);
        waterlow=find(min(z)==z);
        z=abs(MRS_struct.freq-3.8);
        waterhigh=find(min(z)==z);
        freqbounds=waterlow:waterhigh;
        % Do the water fit (Lorentz-Gauss)
        % 111209 Always do the LSQCURV fitting - to initialise
            %Lorentz-Gauss Starters
            options = optimset('lsqcurvefit');
            options = optimset(options,'Display','off','TolFun',1e-10,'Tolx',1e-10,'MaxIter',10000);
            [LGModelParam(ii,:),residual(ii), residw] = lsqcurvefit(@(xdummy,ydummy) ...
                LorentzGaussModel(xdummy,ydummy),...
                LGModelInit, freq(freqbounds),real(WaterData(ii,freqbounds)),...
                lblg,ublg,options);
              residw = -residw;
            if(waterfit_method == FIT_NLINFIT)
                LGModelInit = LGModelParam(ii,:); % CJE 4 Jan 12   
                % nlinfit options
                nlinopts = statset('nlinfit');
                nlinopts = statset(nlinopts, 'MaxIter', 1e5);
                %This double fit doesn't seem to work too well with the GE
                %data... dig a little deeper
                LGPModelInit = [maxinWater 20 4.7 0 waterbase -50 0];
                [LGPModelParam(ii,:),residw] = nlinfit(freq(freqbounds), real(WaterData(ii,freqbounds)),...
                    @(xdummy,ydummy)	LorentzGaussModelP(xdummy,ydummy),...
                    LGPModelInit, nlinopts);
                if(~strcmpi(MRS_struct.vendor,'GE')&&~strcmpi(MRS_struct.vendor,'Siemens'))
                    %remove phase and run again
                    WaterData(ii,:)=WaterData(ii,:)*exp(1i*LGPModelParam(ii,7));
                    LGPModelParam(ii,7)=0;
                    [LGPModelParam(ii,:),residw] = nlinfit(freq(freqbounds), real(WaterData(ii,freqbounds)),...
                    @(xdummy,ydummy)	LorentzGaussModelP(xdummy,ydummy),...
                    LGPModelParam(ii,:), nlinopts);
                end
                residw = -residw;
            end
        MRS_struct.WaterModelParam(ii,:) = LGPModelParam(ii,:);

        hb=subplot(2, 2, 3);
        waterheight = LGPModelParam(ii,1);
        watmin = min(real(WaterData(ii,:)));
        watmax = max(real(WaterData(ii,:)));
        resmax = max(residw);
        MRS_struct.WaterFitError(ii)  =  100 * std(residw) / waterheight; %raee changed to residw
        residw = residw + watmin - resmax;
        stdevresidw=std(residw);
        MRS_struct.GABAIU_Error_w = (MRS_struct.GABAFitError .^ 2 + ...
            MRS_struct.WaterFitError .^ 2 ) .^ 0.5;
        plot(freq(freqbounds),real(LorentzGaussModelP(LGPModelParam(ii,:),freq(freqbounds))), 'r', ...
            freq(freqbounds),real(WaterData(ii,freqbounds)),'b', ...
            freq(freqbounds), residw, 'k');
        set(gca,'XDir','reverse');
        set(gca,'YTick',[]);
        xlim([4.2 5.2]);
        %Add on some labels
        hwat=text(4.8,watmax/2,'Water');
        set(hwat,'horizontalAlignment', 'right');
        %Get the right vertical offset for the residual label
        z=abs(freq(freqbounds)-4.4);
        waterrlow=find(min(z)==z);
        z=abs(freq(freqbounds)-4.25);
        waterrhigh=find(min(z)==z);
        rlabelbounds=waterrlow:waterrhigh;
        labelfreq=freq(freqbounds);
        hwatres=text(4.4,min(residw(rlabelbounds))-0.05*watmax,'residual');
        set(hwatres,'horizontalAlignment', 'left');       
        %CJE fixes water baseline code - baseline model as before...
        WaterArea(ii)=sum(real(LorentzGaussModel(LGModelParam(ii,:),freq(freqbounds))) ...
      - BaselineModel(LGModelParam(ii,3:5),freq(freqbounds)),2);
        % convert watersum to integral
        MRS_struct.waterArea(ii)=WaterArea(ii) * (freq(1) - freq(2));
        %MRS_struct.H20 = MRS_struct.waterArea(ii) ./ std(residw); %This line doesn't make sense - commenting pending delete. RE
        %generate scaled spectrum (for plotting) CJE Jan2011
        MRS_struct.spec.diff_scaled(ii,:) = MRS_struct.spec.diff(ii,:) .* ...
            repmat((1 ./ MRS_struct.waterArea(ii)), [1 32768]);
    %Concentration of GABA to water determined here.
        [MRS_struct]=MRSGABAinstunits(MRS_struct, ii);
    end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 
% 3.  Cr Fit 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%    
Cr_OFF=MRS_struct.spec.off(ii,:);        
%Fit CHo and Cr
    ChoCrFitLimLow=2.6;
    ChoCrFitLimHigh=3.6;           
    %Still need ranges for Creatine align plot
    z=abs(MRS_struct.freq-ChoCrFitLimHigh);
    cclb=find(min(z)==z);
    z=abs(MRS_struct.freq-ChoCrFitLimLow);
    ccub=find(min(z)==z);
    freqrangecc=MRS_struct.freq(cclb:ccub);
    %Do some detective work to figure out the initial parameters
    ChoCrMeanSpec = Cr_OFF(cclb:ccub).';
    Baseline_offset=real(ChoCrMeanSpec(1)+ChoCrMeanSpec(end))/2;
    Width_estimate=0.05;%ppm
    Area_estimate=(max(real(ChoCrMeanSpec))-min(real(ChoCrMeanSpec)))*Width_estimate*4;
    ChoCr_initx = [ Area_estimate Width_estimate 3.02 0 Baseline_offset 0 1].*[1 (2*MRS_struct.LarmorFreq) MRS_struct.LarmorFreq (180/pi) 1 1 1];     
    ChoCrMeanSpecFit(ii,:) = FitChoCr(freqrangecc, ChoCrMeanSpec, ChoCr_initx,MRS_struct.LarmorFreq);
    MRS_struct.ChoCrMeanSpecFit(ii,:) = ChoCrMeanSpecFit(ii,:)./[1 (2*MRS_struct.LarmorFreq) MRS_struct.LarmorFreq (180/pi) 1 1 1];

        %Initialise fitting pars
        z=abs(MRS_struct.freq-3.12);
        lb=find(min(z)==z);
        z=abs(MRS_struct.freq-2.72);
        ub=find(min(z)==z);
        Cr_initx = [max(real(Cr_OFF(lb:ub))) 0.05 3.0 0 0 0 ];
        freqrange = MRS_struct.freq(lb:ub);
        %Then use the same function as the Cr Fit in GannetLoad
        nlinopts=statset('nlinfit');
        nlinopts = statset(nlinopts, 'MaxIter', 1e5, 'Display','Off');
        [CrFitParams(ii,:), residCr] = nlinfit(freqrange, real(Cr_OFF(lb:ub)), ...
            @(xdummy, ydummy) LorentzModel(xdummy, ydummy),Cr_initx, nlinopts);
        Crheight = CrFitParams(ii,1);
        Crmin = min(real(Cr_OFF(lb:ub)));
        Crmax = max(real(Cr_OFF(lb:ub)));
        resmaxCr = max(residCr);
        stdresidCr = std(residCr);
        MRS_struct.CrFitError(ii)  =  100 * stdresidCr / Crheight;
        MRS_struct.GABAIU_Error_cr(ii) = (MRS_struct.GABAFitError(ii) .^ 2 + ...
            MRS_struct.CrFitError(ii) .^ 2 ) .^ 0.5;
        %MRS_struct.CrArea(ii)=sum(real(LorentzModel(CrFitParams(ii,:),freqrange)-LorentzModel([0 CrFitParams(ii,2:end)],freqrange))) * (freq(1) - freq(2));
        MRS_struct.CrArea(ii)=sum(real(TwoLorentzModel([MRS_struct.ChoCrMeanSpecFit(ii,1:(end-1)) 0],freqrangecc)-TwoLorentzModel([0 MRS_struct.ChoCrMeanSpecFit(ii,2:(end-1)) 0],freqrangecc))) * (freq(1) - freq(2));
        MRS_struct.ChoArea(ii)=sum(real(TwoLorentzModel([MRS_struct.ChoCrMeanSpecFit(ii,1:(end))],freqrangecc)-TwoLorentzModel([MRS_struct.ChoCrMeanSpecFit(ii,1:(end-1)) 0],freqrangecc))) * (freq(1) - freq(2));
        MRS_struct.gabaiuCr(ii)=MRS_struct.gabaArea(ii)./MRS_struct.CrArea(ii);           
        MRS_struct.gabaiuCho(ii)=MRS_struct.gabaArea(ii)./MRS_struct.ChoArea(ii);           
        %alter resid Cr for plotting.
        residCr = residCr + Crmin - resmaxCr;
        if strcmp(MRS_struct.Reference_compound,'H2O')
            %Plot the Cr fit
            h2=subplot(2, 2, 4);
            %debugging changes
            plot(freqrangecc,real(TwoLorentzModel(MRS_struct.ChoCrMeanSpecFit(ii,:),freqrangecc)), 'r', ...
                freqrangecc,real(TwoLorentzModel([MRS_struct.ChoCrMeanSpecFit(ii,1:(end-1)) 0],freqrangecc)), 'r', ...
                MRS_struct.freq,real(Cr_OFF(:)),'b', ...
                freqrange, residCr, 'k');
            set(gca,'XDir','reverse');
            set(gca,'YTick',[],'Box','off');
            xlim([2.6 3.6]);
            hcr=text(2.94,Crmax*0.75,'Creatine');
            set(hcr,'horizontalAlignment', 'left')
            %Transfer Cr plot into insert
            subplot(2,2,3)
            [h_m h_i]=inset(hb,h2);
            set(h_i,'fontsize',6)
            %Add labels
            hwat=text(4.8,watmax/2,'Water');
            set(hwat,'horizontalAlignment', 'right')
            set(h_m,'YTickLabel',[]);
            set(h_m,'XTickLabel',[]);
        else
            %Plot the Cr fit
            hb=subplot(2, 2, 3);
            %debugging changes
            plot(freqrange,real(LorentzModel(CrFitParams(ii,:),freqrange)), 'r', ...
                MRS_struct.freq,real(Cr_OFF(:)),'b', ...
                freqrange, residCr, 'k');            
            set(gca,'XDir','reverse');
            set(gca,'YTick',[]);
            xlim([2.6 3.6]);
            z=abs(freq(lb:ub)-3.12);
            crlow=find(min(z)==z);
            z=abs(freq(lb:ub)-2.9);
            crhigh=find(min(z)==z);
            crlabelbounds=crlow:crhigh;
            hcres=text(3.12,max(residCr(crlabelbounds))+0.05*Crmax,'residual');
            set(hcres,'horizontalAlignment', 'left');
            hcdata=text(2.8,0.3*Crmax,'data','Color',[0 0 1]);
            hcmodel=text(2.8,0.2*Crmax,'model','Color',[1 0 0]);
            text(2.94,Crmax*0.75,'Creatine');
        end

    % GABA fitting information
    if(strcmp(MRS_struct.AlignTo,'no')~=1)
        tmp2 = '1';
    else
        tmp2 = '0';
    end
    if fit_method == FIT_NLINFIT
        tmp3 = 'NLINFIT, ';
    else
        tmp3 = 'LSQCURVEFIT, ';
    end
    if waterfit_method == FIT_NLINFIT
        tmp4 = [tmp3 'NLINFIT'];
    else
        tmp4 = [tmp3 'LSQCURVEFIT' ];
    end


    %and running the plot
    subplot(2,2,2)
    axis off
      if strcmp(MRS_struct.vendor,'Siemens')
         tmp = [ 'filename    : ' MRS_struct.gabafile{ii*2-1} ];
     else
        tmp = [ 'filename    : ' MRS_struct.gabafile{ii} ];
     end
    tmp = regexprep(tmp, '_','-');
    text(0,0.9, tmp);
    tmp =       [ 'Navg         : ' num2str(MRS_struct.Navg(ii)) ];
    text(0,0.8, tmp);
    tmp = sprintf('GABA+ FWHM   : %.2f Hz', MRS_struct.GABAFWHM(ii) );
    text(0,0.7, tmp);
    tmp = sprintf('GABA+ Area   : %.4f', MRS_struct.gabaArea(ii) );
    text(0,0.6, tmp);
    if strcmp(MRS_struct.Reference_compound,'H2O')
        tmp = sprintf('H2O/Cr Area   :%.3f/%.3f ', MRS_struct.waterArea(ii),MRS_struct.CrArea(ii) );
        text(0,0.5, tmp);
        tmp = sprintf('%.2f, %.2f ',  MRS_struct.GABAIU_Error_w(ii),  MRS_struct.GABAIU_Error_cr(ii));
        tmp = [tmp '%'];
        tmp = ['FtErr (H/Cr) : ' tmp];
        text(0,0.4, tmp);
        tmp = sprintf('GABA+ / H_2O  : %.4f inst. units.', MRS_struct.gabaiu(ii) );
        text(0,0.3, tmp);
        tmp = sprintf('GABA+/Cr i.r.: %.4f', MRS_struct.gabaiuCr(ii) );
        text(0,0.2, tmp);
        tmp =       [ 'Ver(Load/Fit): ' MRS_struct.versionload ',' tmp2 ',' MRS_struct.versionfit];
        text(0,0.1, tmp);
        tmp =        ['GABA, Water fit alg. :' tmp4 ];
        text(0,-0.1, tmp, 'FontName', 'Courier');
    else
        tmp = sprintf('Cr Area      : %.4f', MRS_struct.CrArea(ii) );
        text(0,0.5, tmp);
        tmp = sprintf('FitError (Cr): %.2f%%', MRS_struct.GABAIU_Error_cr);
        text(0,0.4, tmp);
        tmp = sprintf('GABA+/Cr i.r.: %.4f', MRS_struct.gabaiuCr(ii) );
        text(0,0.3, tmp);
        tmp =       [ 'Ver(Load/Fit): ' MRS_struct.versionload ',' tmp2 ',' MRS_struct.versionfit];
        text(0,0.2, tmp);
        tmp =        ['GABA, Water fit alg. :' tmp4 ];
        text(0,0.0, tmp);
    end
    %Add Gannet logo
    subplot(2,2,4,'replace')
    axis off;
    script_path=which('Gannet2Fit');
    Gannet_circle_white=[script_path(1:(end-12)) 'GANNET_circle_white.jpg'];
    A_2=imread(Gannet_circle_white);
    hax=axes('Position',[0.80, 0.05, 0.15, 0.15]);
    image(A_2);axis off; axis square;

    %%%%  Save EPS %%%%%
    if strcmp(MRS_struct.vendor,'Siemens')
    pfil_nopath = MRS_struct.gabafile{ii*2-1};
    else
    pfil_nopath = MRS_struct.gabafile{ii};
    end
    %for philips .data
    if(strcmpi(MRS_struct.vendor,'Philips_data'))
        fullpath = MRS_struct.gabafile{ii};
        fullpath = regexprep(fullpath, '\./', '');
        fullpath = regexprep(fullpath, '/', '_');
    end
    tmp = strfind(pfil_nopath,'/');
    tmp2 = strfind(pfil_nopath,'\');
    if(tmp)
        lastslash=tmp(end);
    elseif (tmp2)
        %maybe it's Windows...
        lastslash=tmp2(end);
    else
        % it's in the current dir...
        lastslash=0;
    end
    if(strcmpi(MRS_struct.vendor,'Philips'))
        tmp = strfind(pfil_nopath, '.sdat');
        tmp1= strfind(pfil_nopath, '.SDAT');
        if size(tmp,1)>size(tmp1,1)
            dot7 = tmp(end); % just in case there's another .sdat somewhere else...
        else
            dot7 = tmp1(end); % just in case there's another .sdat somewhere else...
        end
    elseif(strcmpi(MRS_struct.vendor,'GE'))
        tmp = strfind(pfil_nopath, '.7');
        dot7 = tmp(end); % just in case there's another .7 somewhere else...
    elseif(strcmpi(MRS_struct.vendor,'Philips_data'))
        tmp = strfind(pfil_nopath, '.data');
        dot7 = tmp(end); % just in case there's another .data somewhere else...
    elseif(strcmpi(MRS_struct.vendor,'Siemens'))
        tmp = strfind(pfil_nopath, '.rda');
        dot7 = tmp(end); % just in case there's another .data somewhere else...
    end
    pfil_nopath = pfil_nopath( (lastslash+1) : (dot7-1) );
    if sum(strcmp(listfonts,'Helvetica'))>0
           set(findall(h,'type','text'),'FontName','Helvetica')
           set(ha,'FontName','Helvetica')
           set(hb,'FontName','Helvetica')
    end
    %Save pdf output
    set(gcf, 'PaperUnits', 'inches');
    set(gcf,'PaperSize',[11 8.5]);
    set(gcf,'PaperPosition',[0 0 11 8.5]);
    if(strcmpi(MRS_struct.vendor,'Philips_data'))
        pdfname=[ epsdirname '/' fullpath '.pdf' ];
    else
        pdfname=[ epsdirname '/' pfil_nopath  '.pdf' ];
    end
    epsdirname
    if(exist(epsdirname,'dir') ~= 7)
        epsdirname
        mkdir(epsdirname)
    end
    saveas(gcf, pdfname);
    
    
% Dec 09: based on FitSeries.m:  Richard's GABA Fitting routine
%     Fits using GaussModel
% Feb 10: Change the quantification method for water.  Regions of poor homogeneity (e.g. limbic)
%     can produce highly asymetric lineshapes, which are fitted poorly.  Don't fit - integrate
%     the water peak.
% March 10: 100301
%           use MRS_struct to pass loaded data data, call MRSGABAinstunits from here.
%           scaling of fitting to sort out differences between original (RE) and my analysis of FEF data
%           change tolerance on gaba fit
% 110308:   Keep definitions of fit functions in MRSGABAfit, rather
%               than in separate .m files
%           Ditto institutional units calc
%           Include FIXED version of Lorentzian fitting
%           Get Navg from struct (need version 110303, or later of
%               MRSLoadPfiles
%           rejig the output plots - one fig per scan.
% 110624:   set parmeter to choose fitting routine... for awkward spectra
%           report fit error (100*stdev(resid)/gabaheight), rather than "SNR"
%           can estimate this from confidence interval for nlinfit - need
%               GABA and water estimates

% 111111:   RAEE To integrate in Philips data, which doesn't always have
% water spectr, we need to add in referenceing to Cr... through
% MRS_struct.Reference_compound

%111214 integrating CJE's changes on water fitting (pre-init and revert to
%linear bseline). Also investigating Navg(ii)

    
end

% end of MRSGABAfit

%%%%%%%%%%%%%%%%%%%%%%%% GAUSS MODEL %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function F = GaussModel_area(x,freq)

% x(1) = gaussian amplitude
% x(2) = 1/(2*sigma^2)
% x(3) = centre freq of peak
% x(4) = amplitude of linear baseline
% x(5) = constant amplitude offset

%F = x(1)*sqrt(-x(2)/pi)*exp(x(2)*(freq-x(3)).*(freq-x(3)))+x(4)*(freq-x(3))+x(5);
F = x(1)*exp(x(2)*(freq-x(3)).*(freq-x(3)))+x(4)*(freq-x(3))+x(5);



%%%%%%%%%%%%%%%%  OLD LORENTZGAUSSMODEL %%%%%%%%%%%%%%%%%%%%
%function F = LorentzGaussModel(x,freq)
%Lorentzian Model multiplied by a Gaussian.  gaussian width determined by
%x(6). x(7) determines phase.
%F = ((ones(size(freq))./(x(2)^2*(freq-x(3)).*(freq-x(3))+1)*x(1))*cos(x(7))+(ones(size(freq))./(x(2)^2*(freq-x(3)).*(freq-x(3))+1)*x(2).*(freq-x(3)))*sin(x(7))).*(exp(x(6)*(freq-x(3)).*(freq-x(3))))+x(4)*(freq-x(3))+x(5);


%%%%%%%%%%%%%%%%  LORENTZGAUSSMODEL %%%%%%%%%%%%%%%%%%%%
function F = LorentzGaussModel(x,freq)
% CJE 24Nov10 - removed phase term from fit - this is now dealt with
% by the phasing of the water ref scans in MRSLoadPfiles
%Lorentzian Model multiplied by a Gaussian.
% x(1) = Amplitude of (scaled) Lorentzian
% x(2) = 1 / hwhm of Lorentzian (hwhm = half width at half max)
% x(3) = centre freq of Lorentzian
% x(4) = linear baseline slope
% x(5) = constant baseline amplitude
% x(6) =  -1 / 2 * sigma^2  of gaussian

% Lorentzian  = (1/pi) * (hwhm) / (deltaf^2 + hwhm^2)
% Peak height of Lorentzian = 4 / (pi*hwhm)
% F is a normalised Lorentzian - height independent of hwhm
%   = Lorentzian / Peak

%F =((ones(size(freq))./(x(2)^2*(freq-x(3)).*(freq-x(3))+1)*x(1))*cos(x(7))+(ones(size(freq))./(x(2)^2*(freq-x(3)).*(freq-x(3))+1)*x(2).*(freq-x(3)))*sin(x(7))).*(exp(x(6)*(freq-x(3)).*(freq-x(3))))+x(4)*(freq-x(3))+x(5);
% remove phasing
F = (x(1)*ones(size(freq))./(x(2)^2*(freq-x(3)).*(freq-x(3))+1))  ...
    .* (exp(x(6)*(freq-x(3)).*(freq-x(3)))) ... % gaussian
    + x(4)*(freq-x(3)) ... % linear baseline
    +x(5); % constant baseline

%%%%%%%%%%%%%%%%  NEW LORENTZGAUSSMODEL WITH PHASE%%%%%%%%%%%%%%%%%%%%
function F = LorentzGaussModelP(x,freq)
% CJE 24Nov10 - removed phase term from fit - this is now dealt with
% by the phasing of the water ref scans in MRSLoadPfiles
%Lorentzian Model multiplied by a Gaussian.
% x(1) = Amplitude of (scaled) Lorentzian
% x(2) = 1 / hwhm of Lorentzian (hwhm = half width at half max)
% x(3) = centre freq of Lorentzian
% x(4) = linear baseline slope
% x(5) = constant baseline amplitude
% x(6) =  -1 / 2 * sigma^2  of gaussian
% x(7) = phase (in rad)

% Lorentzian  = (1/pi) * (hwhm) / (deltaf^2 + hwhm^2)

% Peak height of Lorentzian = 4 / (pi*hwhm)
% F is a normalised Lorentzian - height independent of hwhm
%   = Lorentzian / Peak

%F =((ones(size(freq))./(x(2)^2*(freq-x(3)).*(freq-x(3))+1)*x(1))*cos(x(7))+(ones(size(freq))./(x(2)^2*(freq-x(3)).*(freq-x(3))+1)*x(2).*(freq-x(3)))*sin(x(7))).*(exp(x(6)*(freq-x(3)).*(freq-x(3))))+x(4)*(freq-x(3))+x(5);
% remove phasing
F = ((cos(x(7))*x(1)*ones(size(freq))+sin(x(7)*x(1)*x(2)*(freq-x(3))))./(x(2)^2*(freq-x(3)).*(freq-x(3))+1))  ...
    .* (exp(x(6)*(freq-x(3)).*(freq-x(3)))) ... % gaussian
    + x(4)*(freq-x(3)) ... % linear baseline
    +x(5); % constant baseline

%%%%%%%%%%%%%%% BASELINE %%%%%%%%%%%%%%%%%%%%%%%
function F = BaselineModel(x,freq)
F = x(2)*(freq-x(1))+x(3);


%%%%%%%%%%%%%%%%%%% INST UNITS CALC %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [MRS_struct] = MRSGABAinstunits(MRS_struct,ii)
% function [MRS_struct] = MRSGABAinstunits(MRS_struct)
% Convert GABA and Water amplitudes to institutional units
% (pseudo-concentration in mmol per litre).
% March 10: use MRS_struct.

PureWaterConc = 55000; % mmol/litre
WaterVisibility = 0.65; % This is approx the value from Ernst, Kreis, Ross
EditingEfficiency = 0.5;
T1_GABA = 0.80 ; % "empirically determined"...! Gives same values as RE's spreadsheet
% ... and consistent with Cr-CH2 T1 of 0.8 (Traber, 2004)
%Not yet putting in measured GABA T1, but it is in the pipeline - 1.35ish

T2_GABA = 0.13; % from occipital Cr-CH2, Traber 2004
T2_GABA = 0.088; % from JMRI paper 2011 Eden et al.

T1_Water = 1.100; % average of WM and GM, estimated from Wansapura 1999
T2_Water = 0.095; % average of WM and GM, estimated from Wansapura 1999
MM=0.45;  % MM correction: fraction of GABA in GABA+ peak. (In TrypDep, 30 subjects: 55% of GABA+ was MM)
%This fraction is platform and implementation dependent, base on length and
%shape of editing pulses and ifis Henry method. 
%
TR=MRS_struct.TR/1000;
TE=0.068;
N_H_GABA=2;
N_H_Water=2;
Nspectra = length(MRS_struct.gabafile);
%Nwateravg=8;

T1_factor = (1-exp(-TR./T1_Water)) ./ (1-exp(-TR./T1_GABA));
T2_factor = exp(-TE./T2_Water) ./ exp(-TE./T2_GABA);

if(strcmpi(MRS_struct.vendor,'Siemens'))
    MRS_struct.gabaiu(ii) = (MRS_struct.gabaArea(ii)  ./  MRS_struct.waterArea(ii))  ...
    * PureWaterConc*WaterVisibility*T1_factor*T2_factor*(N_H_Water./N_H_GABA) ...
    * MM /2.0 ./ EditingEfficiency; %Factor of 2.0 is appropriate for averaged data, read in separately as on and off (Siemens).
else
    MRS_struct.gabaiu(ii) = (MRS_struct.gabaArea(ii)  ./  MRS_struct.waterArea(ii))  ...
    * PureWaterConc*WaterVisibility*T1_factor*T2_factor*(N_H_Water./N_H_GABA) ...
    * MM ./ EditingEfficiency;
end
FAC=PureWaterConc*WaterVisibility*(N_H_Water./N_H_GABA) ...
    * MM ./ EditingEfficiency*T1_factor*T2_factor


%%%%%%%%%%%%%%% INSET FIGURE %%%%%%%%%%%%%%%%%%%%%%%
function [h_main, h_inset]=inset(main_handle, inset_handle,inset_size)

% The function plotting figure inside figure (main and inset) from 2 existing figures.
% inset_size is the fraction of inset-figure size, default value is 0.35
% The outputs are the axes-handles of both.
%
% An examle can found in the file: inset_example.m
%
% Moshe Lindner, August 2010 (C).

if nargin==2
    inset_size=0.35;
end

inset_size=inset_size*.5;
%figure
new_fig=gcf;
main_fig = findobj(main_handle,'Type','axes');
h_main = copyobj(main_fig,new_fig);
set(h_main,'Position',get(main_fig,'Position'))
inset_fig = findobj(inset_handle,'Type','axes');
h_inset = copyobj(inset_fig,new_fig);
ax=get(main_fig,'Position');
set(h_inset,'Position', [1.3*ax(1)+ax(3)-inset_size 1.001*ax(2)+ax(4)-inset_size inset_size*0.7 inset_size*0.9])







