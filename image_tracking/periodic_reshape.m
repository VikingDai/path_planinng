function remat=periodic_reshape(mat,azim)
    global  N_azim     
    %% index grid with real value
    function sub_mat=indexing_mat(index_real,mat)
        % indexing a matrix with real value of azimuth, not just integer
        D_azim=2*pi/N_azim; 
        lower=index_real(1); upper=index_real(2);
                        
        lower_idx=round(lower/D_azim)+1;        
        upper_idx=round(upper/D_azim);        
        
        if upper_idx>size(mat,2)
            upper_idx=upper_idx-1;
        end
        sub_mat=mat(:,lower_idx:upper_idx);        
    end
    %% reshape periodically 
    % 0< azim < 2pi     
    if azim-pi>0
        remat=[indexing_mat([azim-pi 2*pi],mat) indexing_mat([0 azim-pi],mat)];        
    else
         remat=[indexing_mat([azim+pi 2*pi],mat) indexing_mat([0 azim+pi],mat)];       
    end
    
end