%% Description 
% this code simulates a scenario. 

% %% Map setting
% map_dim = 20;
% lx = 10; ly = 10; % size of map in real coordinate 
% res = lx / map_dim;
% custom_map=makemap(20); % draw obstacle interactively
% 
% %% Generate map occupancy grid object 
% 
% map = robotics.OccupancyGrid(flipud(custom_map),1/res);
% show(map);
% [target_xs,target_ys,tracker]=set_target_tracker; % assign target and tracker
% target_xs(e)
%% Get score map from each target point
% 
% vis_cost_set = []; % row : time / col : angle index 
% N_azim = 10;
% 
% for t = 1:length(target_xs)-1 % -1 is due to some mistake in set_target_tracker function 
%     target_position = [target_xs(t), target_ys(t) 0]';
%     ray_len = norm(target_position(1:2) - tracker);
%     ray_lens = ray_len * ones(N_azim,1);
%     angles = linspace(0,2*pi,N_azim+1);
%     angles(end) = [];
%     
%     cast_res = zeros(1,N_azim); % 1 for hit and 0 for free rays    
%     collisionPts=map.rayIntersection(target_position,angles,ray_len); % the NaN elements are not hit, 
%     collisionIdx=find(~isnan(collisionPts(:,1))); % collided index 
%     cast_res(collisionIdx) = 1;
%     DT = signed_distance_transform([cast_res cast_res cast_res]); % periodic distance transform 
%     DT = DT(N_azim+1:2*N_azim); % extracting 
%     vis_cost = max(DT) - DT + 1; 
%     vis_cost_set(t,:) = vis_cost;    
% end

%% Feasible region convex division for LP problem 

% for now, the feasible region for solving discrete path is just rectangle
% (TODO: extension for general affine region)
H = length(target_xs)-1;
x_range = 8;
y_range = 2;
feasible_domain_x = [tracker(1) - x_range/2 tracker(1) + x_range/2];
xl = feasible_domain_x(1);
xu = feasible_domain_x(2);
feasible_domain_y = [tracker(2) - y_range/2  tracker(2)  + y_range/2];
yl = feasible_domain_y(1);
yu = feasible_domain_y(2);

% plot the problem 
show(map)
hold on 
plot(target_xs,target_ys,'r*')
plot(tracker(1),tracker(2),'ko')
patch([xl xu xu xl],[yl yl yu yu],'red','FaceAlpha',0.3)

% A_sub, b_sub : inequality matrix of each sub division region (sigma Nh  pair)
Nh = zeros(1,H); % we also invesigate number of available regions per each time step 
angles = linspace(0,2*pi,N_azim+1);
S = [];

for h = 1:H
    Nk = 0; % initialize number of valid region
    for k = 1:N_azim    
        % Bounding lines of the k th pizza segment !
        theta1 = 2*pi/N_azim * (k-1);
        theta2 = 2*pi/N_azim * (k);        
        v1 = [cos(theta1), sin(theta1)]'; 
        v2 = [cos(theta2) , sin(theta2)]'; 
        % If this holds, then one of the two line is in the box 
        if ( is_in_box(v1,[target_xs(h) ; target_ys(h)],[xl xu],[yl yu]) || is_in_box(v2,[target_xs(h) ; target_ys(h)],[xl xu],[yl yu]) )
            [A,b] = get_ineq_matrix([target_xs(h) ; target_ys(h)],v1,v2);        
            Nk = Nk +1;
            A_sub{h}{Nk} = A; b_sub{h}{Nk}=b; % inequality constraint
            S=[S vis_cost_set(h,k)]; % visbiility cost of the region 
        end          
    end    
    Nh(h) = Nk; % save the available number of region
end

%% Generation of optimal sequence (refer lab note)

%%%
% Optimization variables 
% X = [x1 y1 x2 y2 ... xH yH  ||  d1x d1y ... dHx dHy || j1x j1y ... jHx jHy || z_1,1 z_1,2 ... z_1,N1 | ..| z_H,1 ... z_H,N_H]
% w_v: weight for visibility 
%%%


%%%
% Parameters
% w_j : weight for jerk 
% w_v: weight for visibility 
%%%
H  = length(target_xs)-1 ; % total horizon 
N_var = 2*H + 2*H + 2*H + length(S); % x,y,dx,dy,jx,jy,z
w_j = 1e-3;
w_v = 10;


% objective function : sum of travel (1 norm), sum of jerk, sum of visibility cost  
f = [zeros(1,2*H), ones(1,2*H),  w_j * ones(1,2*H), w_v*S];

% equality constraint
Aeq = zeros(H,N_var);
insert_idx = 6*H + 1;
    
for h = 1:H
    Aeq(h,insert_idx:insert_idx+Nh(h)-1) = ones(1,Nh(h));
    insert_idx = insert_idx+Nh(h)  ;
end
beq = ones(H,1);
   


% inequality 1 : distance auxiliary variables
Aineq1 = zeros(4*H,N_var); bineq1 = zeros(4*H,1);
insert_mat_xy = [-1 0 ; 1 0 ; 0 -1 ; 0 1];
insert_mat_d = [-1 0 ; -1 0; 0 -1; 0 -1];
insert_row = 1;
insert_col = 1;


for h = 1:H
    if h == 1
        Aineq1(insert_row:insert_row+3,insert_col:insert_col + 1) = insert_mat_xy; bineq1(insert_row:insert_row+3) = [-tracker(1) tracker(1) -tracker(2) tracker(2)]';
        Aineq1(insert_row:insert_row+3,insert_col + 2*H  : insert_col + 2*H +1 ) = insert_mat_d;
    else
        Aineq1(insert_row:insert_row+3,insert_col-2:insert_col+1) = [-insert_mat_xy insert_mat_xy];
        Aineq1(insert_row:insert_row+3,insert_col + 2*H : insert_col + 2*H + 1) = insert_mat_d;        
    end    
    insert_row = insert_row + 4;
    insert_col = insert_col + 2;
end

% inequality 2 : distance auxiliary variables

% inequality 3 : distance auxiliary variables





