function [ MRS_struct ] = SiemensTwixRead(MRS_struct, fname,fname_water)
            ii=MRS_struct.ii;
            MRS_struct.global_rescale=1;
%131216 Since twix data is u combined, use same code from GERead to bring in Siemens
%twix data

            %This handles the GABA data - it is needed whatever..
            %Use mapVBVD to pull in data.        
            twix_obj=mapVBVD(fname);
            
            %This code included by kind permission of Jamie Near.
            %Pull in some header information not accessed by mapVBVD
            %Find the magnetic field strength:
            fid=fopen(fname);
            line=fgets(fid);
            index=findstr(line,'sProtConsistencyInfo.flNominalB0');
            equals_index=findstr(line,'= ');
            while isempty(index) || isempty(equals_index)
                line=fgets(fid);
                index=findstr(line,'sProtConsistencyInfo.flNominalB0');
                equals_index=findstr(line,'= ');
            end
            Bo=line(equals_index+1:end);
            Bo=str2double(Bo);
            fclose(fid);
            
            %Get Spectral width and Dwell Time
            fid=fopen(fname);
            line=fgets(fid);
            index=findstr(line,'sRXSPEC.alDwellTime[0]');
            equals_index=findstr(line,'= ');
            while isempty(index) || isempty(equals_index)
                line=fgets(fid);
                index=findstr(line,'sRXSPEC.alDwellTime[0]');
                equals_index=findstr(line,'= ');
            end
            dwelltime=line(equals_index+1:end);
            dwelltime=str2double(dwelltime)*1e-9;
            spectralwidth=1/dwelltime;
            fclose(fid);
            %Get TxFrq
            fid=fopen(fname);
            line=fgets(fid);
            index=findstr(line,'sTXSPEC.asNucleusInfo[0].lFrequency');
            equals_index=findstr(line,'= ');
            while isempty(index) || isempty(equals_index)
                line=fgets(fid);
                index=findstr(line,'sTXSPEC.asNucleusInfo[0].lFrequency');
                equals_index=findstr(line,'= ');
            end
            txfrq=line(equals_index+1:end);
            txfrq=str2double(txfrq);
            fclose(fid);
            
            %Find the number of averages:
            % fid=fopen(fname);
            % line=fgets(fid);
            % index=findstr(line,'ParamLong."lAverages"');
            % while isempty(index)
            %     line=fgets(fid);
            %     index=findstr(line,'ParamLong."lAverages"');
            % end
            % line=fgets(fid);
            % line=fgets(fid);
            % Naverages=str2num(line);
            % fclose(fid);
            %             
            %End of Jamie Near's code
            %Calculate some parameters:
            MRS_struct.sw=spectralwidth;
            MRS_struct.LarmorFreq = Bo*42.577;          
            MRS_struct.nrows = twix_obj.image.NAcq;
            rc_xres = double(twix_obj.image.NCol);
            rc_yres = double(twix_obj.image.NAcq);
            nreceivers = double(twix_obj.image.NCha);
            % Copy it into FullData
            FullData=permute(reshape(double(twix_obj.image()),[twix_obj.image.NCol twix_obj.image.NCha twix_obj.image.NSet twix_obj.image.NIda]),[2 1 4 3]);
            %Undo Plus-minus 
            FullData(:,:,2,:)=-FullData(:,:,2,:);
            FullData=reshape(FullData,[twix_obj.image.NCha twix_obj.image.NCol twix_obj.image.NSet*twix_obj.image.NIda]);
            MRS_struct.Navg(ii) = double(twix_obj.image.NAcq);
            %size(FullData)
            %Left-shift data by number_to_shift
            
            FullData=FullData(:,1:MRS_struct.npoints,:);
            %size(FullData)
            %Combine data based upon first point of FIDs (mean over all
            %averages
            firstpoint=mean(conj(FullData(:,1,:)),3);
            channels_scale=squeeze(sqrt(sum(firstpoint.*conj(firstpoint))));
            firstpoint=repmat(firstpoint, [1 MRS_struct.npoints MRS_struct.nrows])/channels_scale;
            %Multiply the Multichannel data by the firstpointvector
            % zeroth order phasing of spectra
            FullData = FullData.*firstpoint*MRS_struct.global_rescale;
            % sum over Rx channels
            FullData = conj(squeeze(sum(FullData,1)));
            MRS_struct.data =FullData;

        if(nargin==3)
           %Then we additionally need to pull in the water data. 
           twix_obj_water=mapVBVD(fname_water);
           MRS_struct.nrows_water = twix_obj_water.image.NAcq;
           MRS_struct.npoints_water = twix_obj_water.image.NCol;
            % Copy it into WaterData
            WaterData=permute(reshape(double(twix_obj_water.image()),[twix_obj_water.image.NCol twix_obj_water.image.NCha twix_obj_water.image.NSet twix_obj_water.image.NIda]),[2 1 4 3]);
            %Undo Plus-minus 
            WaterData(:,:,2,:)=-WaterData(:,:,2,:);
            WaterData=reshape(WaterData,[twix_obj_water.image.NCha twix_obj_water.image.NCol twix_obj_water.image.NSet*twix_obj_water.image.NIda]);
            
            
            firstpoint_water=mean(conj(WaterData(:,1,:)),3);
            channels_scale=squeeze(sqrt(sum(firstpoint_water.*conj(firstpoint_water))));
            firstpoint_water=repmat(firstpoint_water, [1 MRS_struct.npoints_water MRS_struct.nrows_water])/channels_scale;
            %Multiply the Multichannel data by the firstpointvector
            % zeroth order phasing of spectra
            WaterData = WaterData.*firstpoint_water*MRS_struct.global_rescale;
            % sum over Rx channels
            WaterData = conj(squeeze(sum(WaterData,1)));
            WaterData = squeeze(mean(WaterData(1:MRS_struct.npoints,:),2));
            MRS_struct.data_water =WaterData;
        end
            
end