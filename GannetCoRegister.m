
function MRS_struct = GannetCoRegister(MRS_struct,nii_name)

%Coregistration of MRS voxel volumes to imaging datasets, based on headers. 

MRS_struct.p.coreg = 1;
%Ultimately this switch will not be necessary...
    switch MRS_struct.p.vendor
    
    case 'Philips'

    case 'Philips_data'
        if exist(MRS_struct.gabafile_sdat)
                MRS_struct.p.vendor = 'Philips';
                MRS_struct.gabafile_data = MRS_struct.gabafile;
                MRS_struct.gabafile_data = MRS_struct.gabafile;
                MRS_struct.gabafile = MRS_struct.gabafile_sdat;
                MRS_struct = GannetCoRegister(MRS_struct,nii_name);
                MRS_struct.gabafile = MRS_struct.gabafile_data;
                MRS_struct.p.vendor = 'Philips_data';
        else
        error([MRS_struct.p.vendor ' format does not include voxel location information in the header. See notes in GannetCoRegister.']); 
        %If this comes up, once GannetLoad has been read:
        %1. Switch vendor to Philips
        %       MRS_struct.p.vendor = 'Philips';
        %2. Copy .data filenames.
        %       MRS_struct.gabafile_data = MRS_struct.gabafile;
        %3. Replace the list with the corrsponding SDAT files (in correct order)
        %        MRS_struct.gabafile = {'SDATfile1.sdat' 'SDATfile2.SDAT'};
        %4. Rerun GannetCoRegister
        %       
        %5.  Copy .sdat filenames and replace .data ones. Tidy up.
        %       MRS_struct.gabafile_sdat = MRS_struct.gabafile;
        %       MRS_struct.gabafile = MRS_struct.gabafile_data;
        %       MRS_struct.p.vendor = 'Philips_data'
        end
    case 'Siemens'
        error(['GannetCoRegister does not yet support ' MRS_struct.p.vendor ' data.']);        
    case 'Siemens_twix'
        error(['GannetCoRegister does not yet support ' MRS_struct.p.vendor ' data.']);        
    case 'GE'
        error(['GannetCoRegister does not yet support ' MRS_struct.p.vendor ' data.']);
    end
    
    if (MRS_struct.ii ~= length(nii_name))
       error('The number of nifti files does not match the number of MRS files processed by GannetLoad.'); 
    end
    %Currently only SDAT is supported
    %Run the script...
    for ii=1:length(nii_name)
        fname = MRS_struct.gabafile{ii};
        sparname = [fname(1:(end-4)) MRS_struct.p.spar_string];
        MRS_struct=GannetMask(sparname,nii_name{ii},MRS_struct);
    end
    
    %Build output figure
    h=figure(103);
        set(h, 'Position', [100, 100, 1000, 707]);
        set(h,'Color',[1 1 1]);
        figTitle = ['GannetCoRegister Output'];
        set(gcf,'Name',figTitle,'Tag',figTitle, 'NumberTitle','off');
              

        imagesc(three_plane_img);
        colormap('gray');
        caxis([0 1])
        axis equal;
        axis tight;
        axis off;

end