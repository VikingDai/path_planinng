function sum_jerk=poly_traj_gen(v_set,n_poly,x0,x0dot,waypoints,guidance_waypoints,path_manager)
    % DESCRIPTION
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % this function computes minimum jerk trajectory given waypoints and
    % corresponding velocities (v_set)
    % especially, we set guidance points to detour any obstacle in segment
    % using A *
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    % INPUTS 
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % v_set : flattened velocity vector of each waypoint (2N_seg x 1)
    % n_poly: polynomial order of each spline 
    % x0/x0dot : initial position / vel (2 x 1)
    % waypoints : cell of waypoints ()
    % path_managers : we store polynomial coefficient to this class 
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    % OUTPUTS
    % sum of jerk along the whole spline curves     
    
  %% PARSING
    n=n_poly;
    n_seg=length(waypoints);
    v_set=reshape(v_set,2,[])';
       
   
    sum_jerk=0;
            
    for seg=1:n_seg
        % initial condition 
        if seg==1
            x_init=x0; xdot_init=x0dot;            
        else
            x_init=waypoints{seg-1}; xdot_init=v_set(seg-1,:);
        end
        
        xd=waypoints{seg}(1); yd=waypoints{seg}(2);                                        
        xdotd=v_set(seg,1); ydotd=v_set(seg,2);
        
        %% GUIDANCE WAYPOINTS TO DETOUR THE OBSTACLES
        N_guide=1;
        if ~isempty(guidance_waypoints{seg})                
            t_guide=linspace(0,1,N_guide+2);
            t_guide=t_guide(2:end-1);
            guidance_pnts=guidance_waypoints{seg};
            for j=1:N_guide
                Qgx= path_manager.t_vec(n,t_guide(j),0)*path_manager.t_vec(n,t_guide(j),0)';
                Qgy=Qgx;
                Hgx=-2 * guidance_pnts(j,1) * path_manager.t_vec(n,t_guide(j),0)'; 
                Hgy=-2 * guidance_pnts(j,2) * path_manager.t_vec(n,t_guide(j),0)';                        
            end        
            w=1e+3;                
            Qgx=Qgx*w; Qgy=Qgy*w; Hgx=Hgx*w; Hgy=Hgy*w;
        else
            Qgx=zeros(n+1); Qgy=Qgx; Hgx=zeros(1,n+1); Hgy=Hgx;          
        end
        %% QP SOLVE        
        % waypoint equality constraints 
        Aeq=[path_manager.t_vec(n,0,0)' ; path_manager.t_vec(n,0,1)' ; path_manager.t_vec(n,1,0)' ; path_manager.t_vec(n,1,1)' ];
        beqx=[x_init(1) ; xdot_init(1) ; xd ; xdotd]; beqy=[x_init(2) ; xdot_init(2) ; yd ; ydotd];
        Q=path_manager.Q_a;
        options = optimoptions('quadprog','Display','off');
        [path_manager.px{seg},seg_jerk_x]  = quadprog(2*Q+2*Qgx,Hgx,[],[],Aeq,beqx,[],[],[],options);
        [path_manager.py{seg},seg_jerk_y]  = quadprog(2*Q+2*Qgy,Hgy,[],[],Aeq,beqy,[],[],[],options);     
        
        sum_jerk=sum_jerk+seg_jerk_x+seg_jerk_y;            
    end
    

   
end
