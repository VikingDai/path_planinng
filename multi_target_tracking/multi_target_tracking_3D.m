%% Description
% this code simulates a scenario. 

addpath('..\ASAP1','.\','..\plotregion\');
addpath('..\STOMP\')
addpath('..\intercept\') % for Rplot and proj_image
addpath('polytopes_2017_10_04_v1.9\')

%% Phase1 : Map setting in 2D projection space

map_dim = 30;
lx = 10; ly = 10; % size of map in real coordinate 
res = lx / map_dim;


% this is problem settings block 
%%%%%%%%%%%%
figure
hold on 
custom_map=makemap(map_dim); % draw obstacle interactively
% load('problem_settings.mat')
% tracker = [1.4 1.4 2.0]';

% Generate map occupancy grid object and path of the two targets
map = robotics.OccupancyGrid(flipud(custom_map),1/res);
show(map);
[target1_xs,target1_ys,target2_xs,target2_ys,tracker]=set_target_tracker2; % assign path of two targets and tracker
%%%%%%%%%%%%

%% 
% packing the target paths (should be same length)
targets_xs = [target1_xs ; target2_xs];
targets_ys = [target1_ys ; target2_ys];


% Clustering and give height for each obstacle 
epsilon=1; % neihbor hood bound 
MinPts=5; % minimum grouping index 
[occ_rows,occ_cols] = find(map.occupancyMatrix >= map.OccupiedThreshold);
occ_cells= [occ_rows occ_cols];
IDX=DBSCAN(occ_cells,epsilon,MinPts);
figure
PlotClusterinResult(occ_cells,IDX)

% Height setting is specific for map settings

% heights = [2,0.2, 5];
% heights_start = [0 2 0];
heights = [2, 5];
heights_start = [0 0];


% Construct 3D map from 2D ground plan 
map3 = robotics.OccupancyMap3D(map.Resolution);
res = map.Resolution;

boxes = {};

pcl = []; % should be N x 3
for idx = 1:max(IDX)
    xy_pnts=map.grid2world(occ_cells(find(IDX==idx),:));
    
    boxes{idx}.lower = [min(xy_pnts) 0];
    boxes{idx}.upper = [max(xy_pnts) heights(idx)];
    
    for r = 1:size(xy_pnts,1)
            zs = heights_start(idx) + (0:1/res/2:heights(idx));
            for z = zs                
                % point cloud append 
                pcl = [pcl ; [xy_pnts(r,:) z]] ;               
            end
    end              
end

pcl_origin_pose = [ 0 0 0  1 0 0 0];  
max_range = 20;
if ~isempty(pcl) 
    map3.insertPointCloud(pcl_origin_pose,pcl,max_range);
end
figure
show(map3)
axis vis3d off

axis equal
hold on 
N_target = 2; % only two targets will be considered

% path of each target 
target1_xs = targets_xs(1,:); target1_ys = targets_ys(1,:);  targets_zs(1,:) = 0.5*ones(1,length(target1_xs));
target2_xs  = targets_xs(2,:); target2_ys = targets_ys(2,:); targets_zs(2,:) = 0.5*ones(1,length(target1_xs));

plot(target1_xs,target1_ys,'r^-','LineWidth',2)
plot(target2_xs,target2_ys,'r^-','LineWidth',2)
plot(tracker(1),tracker(2),'mo','MarkerFaceColor',[1 0 1],'MarkerSize',3)

vis_cost_sets = {};
hold off 
%% Phase2: Get score maps and inequality condition set of each target during a prediction horizon

% parameter for observation 
d_ref = 2;
N_azim = [40,40];
N_elev = [20, 20];

% parameter for sub-division             
N_rect = 10; r_max_stride = 5; % caution: should not be bigger than N_azim/4
c_max_stride = 6; stride_res = 1;                

% visi info 
visi_info_set = {}; % idx = 1 : target1 / idx =2 : target2

for n = 1:N_target 
    target_xs = targets_xs(n,:);
    target_ys = targets_ys(n,:);
    target_zs = targets_zs(n,:);
    visi_info = {}; % information on At_set,bt_set,visi_cost_set_t
    
    cost_set_t = {}; % 1th idx  : time / 2nd idx : just index in the time 
    A_set_t = {}; % set of affine region at the time t
    b_set_t = {};
    
    cost_set_t_flat = {}; % s indexing is removed (s index in fact for the convenience to coloring )
    A_set_t_flat = {};
    b_set_t_flat = {};
    
    rect_set_t ={}; % four corner of of each rect 
    DT_t = {}; % distance field of each agent at time t 
    
    for t = 1:length(target_xs) % -1 is due to some mistake in set_target_tracker function 
         Nt = 0; % number of sub-division rect 

        %% Inter-occlusion prevention 
        
        if n == 1 % other agent will be 2
            other_agent_loc = [targets_xs(2,t) targets_ys(2,t) 1];
        else % other agent will be 1            
            other_agent_loc = [targets_xs(1,t) targets_ys(1,t) 1] ;
        end
                
        map3_h = copy(map3); % map3 object considering the presence of other agent 

        % should do this twice for update 
        map3_h.updateOccupancy(other_agent_loc,1);
        map3_h.updateOccupancy(other_agent_loc,1);

        move_x = [-1,0,1];
        move_y = [-1,0,1];
        move_z = [-1 0 1];
        
        res_stride = 1;
                
        % for clarity, we should inflate the occupancy around the other (but too conservative)
        % agent         
        for i = 1:3
            for j = 1:3
                for k = 1:3
                    for stride = 1:res_stride
                        other_agent_loc_around = other_agent_loc + stride*(1/res) * [move_x(i) move_y(j) move_z(k)];
                        % should do this twice 
                        map3_h.updateOccupancy(other_agent_loc_around,1);
                        map3_h.updateOccupancy(other_agent_loc_around,1);
                    end
                end
            end
        end
        
        %% Contruct inequality condition (polyhydre) from rect region in (azim,elev) space
        
        azim_set = linspace(0,2*pi,N_azim(n)+1);
        azim_set = azim_set(1:end-1);
        
        elev_max = 4*pi/9; elev_min=pi/18;
        elev_set = linspace(elev_min,elev_max,N_elev(n));
        
        max_ray = 6; % maximum allowable tracking distance 
        min_ray =2; % minmum tracking distacne 
        
        ray_cast_res = 1/res;  % ray cast stride distance 
        clustering_delta_r = 1/res; % threshold for neigborhood-ness for hit distance 
        
        [DT_set, pinch_bin]=get_multi_depth_DT(map3_h,[target_xs(t) target_ys(t) target_zs(t)],azim_set,elev_set,max_ray,ray_cast_res,clustering_delta_r);
        % DT set update 
                
        % let's save the pinching process                         
        DT_set_t{t} = DT_set; 
        pinch_bin_t{t} = pinch_bin;
        
        figure() % new figure for this time step and this target 
        title_tot = sprintf('%d th target in %d time step',n,t);
        sgtitle(title_tot)
        
        pinch_bin = [0 pinch_bin];
        
        Nk = 0; % polyhedron indexing 

        
        % pinch_bin : increasing order 
        for s = 1:length(DT_set) % length DT_set = length pinch bin
            
            % SDFT drawing 
            subplot(length(pinch_bin)-1,1,s)                
            title_sub = sprintf('%d th pinch ray length for %.2f',s,pinch_bin(s+1)); 
            title(title_sub)
            
            DT = DT_set{s};
            rect_idx = 0;
            % extract rect region 
            if sum(DT) == inf % no hit occured
                N_row = 3; N_col = 2; % in this case, we just assign decent number to divide the region 
                azim_div = floor(linspace(1,N_azim(n),N_row + 1)); elev_div = floor(linspace(1,N_elev(n),N_col+1));
                rects = {}; % rectangle of this pinch step 

                for r = 1:N_row
                    for c = 1: N_col
                        rect.lower = [azim_div(r),elev_div(c)];
                        rect.upper = [azim_div(r+1),elev_div(c+1)];
                        rect.score = inf; 
                        rect_idx = rect_idx + 1;
                        rects{rect_idx} = rect; 
                    end
                end
                
                plot_DT_rectDiv(10*ones(size(DT,1),size(DT,2)),rects); % in case of no hit.. just plane white for DT 
                
                
            else % if there's hit 
                rects = rectDiv(DT,N_rect,r_max_stride,c_max_stride,stride_res);                    
                
                plot_DT_rectDiv(DT,rects); 
                
            end  

            % enclosing region of this polyhedra segment (6 surfaces or 5 surfaces in the first pinch)
            % these two pinch determine the fore and back enclosing surface
            
            pinch_prev = pinch_bin(s);
            pinch_cur = pinch_bin(s+1);
            
            
           for rect_idx = 1:length(rects)
                
               
                Nk = Nk + 1;
                
                azim1 = azim_set(rects{rect_idx}.lower(1));
                elev1 = elev_set(rects{rect_idx}.lower(2));
                azim2 = azim_set(rects{rect_idx}.upper(1));
                elev2 = elev_set(rects{rect_idx}.upper(2));
                                               
                % two fore and back surface 
                v = [getVec(azim1,elev1) ; getVec(azim1,elev2) ; getVec(azim2,elev2) ; getVec(azim2,elev1)];


                inner_surf_four_corners = [target_xs(t) target_ys(t) target_zs(t)] + pinch_prev *  v; % 4 x 3
                outer_surf_four_corners = [target_xs(t) target_ys(t) target_zs(t)] + pinch_cur *  v; % 4 x 3
                v_center = cross((mean(outer_surf_four_corners) - outer_surf_four_corners(1,:)),(mean(outer_surf_four_corners) - outer_surf_four_corners(4,:)));
                v_center = v_center / norm(v_center);

                
                % inspection 
%                 figure 
%                 hold on 
%                 scatter3(inner_surf_four_corners(:,1),inner_surf_four_corners(:,2),inner_surf_four_corners(:,3),'bo')
%                 scatter3(outer_surf_four_corners(:,1),outer_surf_four_corners(:,2),outer_surf_four_corners(:,3),'ro')
%                 axis equal
%                 
                
                % enclosing lateral surface of this polyhedra segment                 
                A  = [cross(v(1,:),v(2,:)) ; cross(v(2,:),v(3,:)) ; cross(v(3,:),v(4,:)) ; cross(v(4,:),v(1,:)) ; - v_center ; v_center];
                b = [A(1,:) * inner_surf_four_corners(1,:)' ;...
                    A(2,:) * inner_surf_four_corners(2,:)' ;...
                    A(3,:) * inner_surf_four_corners(3,:)';...
                    A(4,:) * inner_surf_four_corners(4,:)';...
                    A(5,:)*  inner_surf_four_corners(1,:)';...
                    A(6,:)*  outer_surf_four_corners(1,:)'];
                                                                                                
                % update  block                                    
                % remind : s is pinch idx / rect_idx 
                A_set_t{t}{s}{rect_idx} = A;
                b_set_t{t}{s}{rect_idx} = b;                                                                  
                cost_set_t{t}{s}(rect_idx) = 1/rects{rect_idx}.score; % should check the value of score (inf value means no hit occured)
                rect_set_t{t}{s}{rect_idx} = rects{rect_idx}; % rectangle 

                % updating - too many dimensional indexing is not tractable                                
                            
                A_set_t_flat{t}{Nk} = A;
                b_set_t_flat{t}{Nk} = b;                                                                  
                cost_set_t_flat{t}{Nk} = 1/rects{rect_idx}.score; % should check the value of score (inf value means no hit occured)
                
                                             
            end % rect

        end % rectangle extraction in (azim,elev) space (pinch)
                
    end % time 
                           
    % save for each agent 
     visi_info.A_set = A_set_t;
     visi_info.b_set = b_set_t;
     visi_info.cost_set = cost_set_t;
     
     visi_info.A_set_flat = A_set_t_flat;
     visi_info.b_set_flat = b_set_t_flat;
     visi_info.cost_set_flat = cost_set_t_flat;
     visi_info.rect_set = rect_set_t;
     visi_info.DT_t = DT_set_t;
     visi_info.pinch_bin = pinch_bin_t;
     
     % append it 
     visi_info_set{n} = visi_info;
         
end % target 


%% Phase 3: plot the visibility affine region of each target respectively 

color_set = [1 0 0;0 0 1]; % for 1st target - red / 2nd target - blue 

H = length(target1_xs);



% plot3(tracker(1),tracker(2),tracker(3),'mo','MarkerFaceColor','m')
% draw_box([xl yl zl],[xu yu zu],'k',0.1)
% height of initial pose of tracker 
margin = 3; 
tracker = [tracker(1) ; tracker(2) ; 2]; 

% domain 
domain_x =[min([tracker(1) reshape(targets_xs,1,[])]) max([tracker(1) reshape(targets_xs,1,[])])];
domain_y =[min([tracker(2) reshape(targets_ys,1,[])]) max([tracker(2) reshape(targets_ys,1,[])])];
domain_z =[min([tracker(3) reshape(targets_zs,1,[])]) max([tracker(3) reshape(targets_zs,1,[])])];

xl = domain_x(1) - margin;
xu = domain_x(2) + margin;

yl = domain_y(1) - margin;
yu = domain_y(2) +margin;

zl = domain_z(1) - margin;
zu = domain_z(2) + margin;

target1_zs = targets_zs(1,:);
target2_zs = targets_zs(2,:);

for n = 1: N_target         
      figure
      title_tot = sprintf('%d th target',n);
      sgtitle(title_tot)
        % only for H = 4

        for h = 1:length(target1_xs)                                            
            subplot(2,2,h)
            show(map3)
            hold on 
            % draw the target 
            if n == 1
                plot3(target1_xs,target1_ys,target1_zs,'r^-','LineWidth',2)
            else
                plot3(target2_xs,target2_ys,target2_zs,'r^-','LineWidth',2)
            end
            

            
            % for pinch 
            for p = 1:length(visi_info_set{n}.A_set{h})

                           % let's secure the max value excluding the inf value
            min_val = 1000;
            max_val = 0;            
 
                % for rect segment in the pinch 
                for s = 1:length(visi_info_set{n}.A_set{h}{p}) 
                    cur_score_vec = 1./visi_info_set{n}.cost_set{h}{p};
                    % we clamping the inf maximum value with non-inf maximum
                    cur_pinch_min=min(cur_score_vec(cur_score_vec ~= inf));    
                    cur_pinch_max = max(cur_score_vec(cur_score_vec ~= inf));                    
                    if min_val > cur_pinch_min
                        min_val=cur_pinch_min;
                    end
                    if max_val < cur_pinch_max
                        max_val = cur_pinch_max;
                    end                    
                end
                
                                
                % for rect segment in the pinch 
                for s = 1:length(visi_info_set{n}.A_set{h}{p}) 
                    alpha = 1/visi_info_set{n}.cost_set{h}{p}(s);
                    if alpha == inf
                        alpha = max_val;
                    end                    
                    [r,g,b]=getRGB(alpha,min_val,max_val,1);
                    plotregion(-visi_info_set{n}.A_set{h}{p}{s},-visi_info_set{n}.b_set{h}{p}{s},[xl yl zl],[xu yu zu],[r g b],0.3);              
                end
            end
            
            axis([xl xu yl yu zl zu])
            axis equal
            
        end
                
end




%% Phase 5 : Combination for divided regions 

% intersection region of the two polyhydra corresponding to each target
FOV = 120 * pi/180;
pruning_vol = 0.1;
A_div = {};
b_div = {};
c_div = {}; % center of each convex polyhedra
v_div = {}; % convex vertex 



vis_cost_set = {};
Nk = 0; % number of valid regions 
ratio = 1; % importance ratio of vis2 to vis1
blind_heights = [];
for h = 1:H    
    A_div{h} = {};
    b_div{h} = {};
    c_div{h} = {};
    v_div{h} = {};
    Nk = 0;
    
    
    
    
    % Firstly, we find blind region of the two targets 
    target1 = [target1_xs(h) target1_ys(h) target1_zs(h)]';
    target2 = [target2_xs(h) target2_ys(h) target2_zs(h)]';
    
    % please put the vector 
    [As_no_blind,bs_no_blind,~,~] = no_blind_region(target1,target2,FOV);
    
    for i = 1:length(visi_info_set{1}.cost_set_flat{h})
        for j = 1:length(visi_info_set{2}.cost_set_flat{h})
            
            % feasibility test for the intersection region of the two
            % polyhedron
                        
            Ai = visi_info_set{1}.A_set_flat{h}{i};
            bi = visi_info_set{1}.b_set_flat{h}{i};
            vis_cost1 = visi_info_set{1}.cost_set_flat{h}{i};
            
            Aj = visi_info_set{2}.A_set_flat{h}{j};
            bj = visi_info_set{2}.b_set_flat{h}{j};
            vis_cost2 = visi_info_set{2}.cost_set_flat{h}{j};
                              
            A_intsec = [Ai ; Aj];
            b_intsec = [bi ; bj];
            
%             % please wait 
%             verr1=con2vert([Ai; A_bound],[bi ; b_bound]);
%             verr2=con2vert([Aj; A_bound],[bj ; b_bound]);
            
                        
            A_bound = [1 0 0; -1 0 0; 0 1 0; 0 -1 0;0 0 1; 0 0 -1];
%             b_bound = [xu ; -xl ; yu ; -yl ; zu ; -(max(target1_zs(h),target2_zs(h))+blind_height)];
            b_bound = [xu ; -xl ; yu ; -yl ; zu ; -zl];

            linprog_options = optimoptions('linprog','Display','none');
            [~,~,flag]=linprog([],[A_intsec; A_bound],[b_intsec ; b_bound],[],[],[],[],[],linprog_options);
            
            
            if (flag ~= -2) % feasibility test pass
               % let's keep this region for now 
               % let's investigate the FOV constraint 
%                  vertices = con2vert([A_bound;A_intsec ],[;b_bound ;b_intsec]); % the vertices of this region   
               
                
                % In case of 3D, the intersection region of two polyhydron
                % can be 2D, which can paralyze the code 
%                 vertices = con2vert([A_bound;A_intsec ],[b_bound ;b_intsec]); % the vertices of this region   
                
               
               for seg = 1:17
                   
                % we investigate if the intersection ([Ai,Aj] , [bi;bj]) belongs to one of no_blind_region    
                [~,~,no_blind_flag] = linprog([],[A_intsec;A_bound ; As_no_blind{seg}],[b_intsec;b_bound;bs_no_blind{seg}],[],[],[],[],[],linprog_options) ;  
                   
                if  (no_blind_flag ~= -2) 
                    
                % let's find vertex to find the volume of the region 
                
                    try  
                        vertices = lcon2vert([A_bound;A_intsec; As_no_blind{seg} ],[;b_bound ;b_intsec ;bs_no_blind{seg}] ); % the vertices of this region   
                   catch
                        warning('no vertex could be found')
                        vertices = [];
                   end               
               
                   if ~isempty(vertices)

                   vertices = vertices + 0.1 * (mean(vertices) - vertices);

                   % we reject the segment the volume is too small                    
                   shp = alphaShape(vertices(:,1),vertices(:,2),vertices(:,3),20);
                   vol = shp.volume;

                       if vol >= pruning_vol
                           Nk = Nk + 1;                     
                           A_div{h}{Nk} = [A_intsec; A_bound ; As_no_blind{seg}];
                           b_div{h}{Nk} = [b_intsec; b_bound ; bs_no_blind{seg}]; 
                           v_div{h}{Nk} =  vertices;
                           c_div{h}{Nk} = mean(vertices); % center of each segment                
                           vis_cost_set{h}(Nk) =  vis_cost1 + ratio * vis_cost2; % let's assign the visibility cost to here    
                       end

                   end % vertex test
               
                end % no blind region test pass 
               end  % no blind segment 
            end    % feasibility test pass
        end        
    end
end
%% Phase 6: plot faesible segment

figure
for h =1 :H 
    subplot(2,H/2,h)                
        
        show(map3)
        axis vis3d off

        hold on 
        plot3(target1_xs,target1_ys,target1_zs,'r^-','LineWidth',2)
       
        plot3(target1_xs(h),target1_ys(h),target1_zs(h),'rs','LineWidth',3,'MarkerSize',10)

        plot3(target2_xs,target2_ys,target2_zs,'r^-','LineWidth',2)
        
        plot3(target2_xs(h),target2_ys(h),target2_zs(h),'rs','LineWidth',3,'MarkerSize',10)

        plot3(tracker(1),tracker(2),tracker(3),'mo','MarkerFaceColor','m')
%         draw_box([xl yl zl],[xu yu zu],'k',0.1)
        
        target1 = [target1_xs(h) target1_ys(h) target1_zs(h)];
        target2 = [target2_xs(h) target2_ys(h) target2_zs(h)];
        
        % we draw blind height 
        
%         patch([xl xl xu xu],[yl yu yu yl],(target1_zs(1)+blind_heights(h))*ones(1,4),'b','FaceAlpha',0.4)
        [~,~,A_blind,b_blind]=no_blind_region(target1',target2',FOV);
        plotregion(-A_blind,-b_blind,[xl yl zl],[xu yu zu],'k',0.3)

        
        for k = 1:length(vis_cost_set{h})        
            
            alpha = 1/vis_cost_set{h}(k);   
            alpha_max = max(1./vis_cost_set{h});
            alpha_min = min(1./vis_cost_set{h});
            if (alpha_max ~= inf) && (alpha ~= inf) && (alpha_min ~= inf)
                [r,g,b]  = getRGB(alpha,alpha_min,alpha_max,1);
            else
                r = 1; g = 0; b = 0;
            end
            
            plotregion(-A_div{h}{k} ,-b_div{h}{k} ,[xl yl zl]',[xu yu zu]',[r,g,b],0.5);
            plot3(c_div{h}{k}(1),c_div{h}{k}(2),c_div{h}{k}(3),'gs','MarkerSize',1.5,'MarkerFaceColor','g');            
        end
        
        axis([xl xu yl yu zl zu])
        axis equal
        
end
%% Phase 7: Astar for the path of region segmentsd

node_name_array = {}; %string -> this will be used in matalb graph library 
node_idx_array={}; % segment index (what time? and what (A,b)?)

name_vec = {'t0n1'};
loc_vec = tracker;
node_name_array{1} = name_vec; % initialize the node name array

w_v = 50; % visibility weight for optimization 
w_d = 1; % weight for desired distance 
d_max = 5; % allowable connecting distane btw "center of region"
Astar_G = digraph();

% for update egde only once at the final phase 
node1_list = {};
node2_list = {};
weight_list = [];
edge_cnt = 0;





for h = 1:H
        % phase1 : add node at this future step
        
        
        
        node_name_array{h+1} = {};

        for name_idx  = 1:length(vis_cost_set{h})
            node_name_array{h+1}{name_idx}  = strcat('t',num2str(h),'n',num2str(name_idx));
        end
        
        Astar_G=Astar_G.addnode(node_name_array{h+1});    
        cur_target_pos = [target_xs(h) ; target_ys(h)];     % target position at this time step 
        
        % phase2: connect edges with previus layer
        for idx1 = 1:length(node_name_array{h}) % previous step
            for idx2 = 1:length(node_name_array{h+1}) % current step                
                % would-be node 
                cur_observ_pnt = c_div{h}{idx2};                 
                if h ~= 1
                    prev_observ_pnt= c_div{h-1}{idx1};
                else
                    prev_observ_pnt = tracker;
                end
                travel_distance = norm([prev_observ_pnt(1) - cur_observ_pnt(1),prev_observ_pnt(2) - cur_observ_pnt(2)]);
                if (travel_distance < d_max) % for sparsity 
                    edge_cnt = edge_cnt + 1;
                    vis_cost = vis_cost_set{h}(idx2);                
                    deviation_d_ref = (d_ref - norm([cur_observ_pnt(1)-cur_target_pos(1),cur_observ_pnt(2)-cur_target_pos(2)]))^2;       
                    weight = w_v*(vis_cost)^2 + w_d*deviation_d_ref + travel_distance;
                    fprintf("weight record : %f / %f / %f\n",w_v*vis_cost^2,w_d*deviation_d_ref ,travel_distance)
                    % add the two connecting nodes with the weight 
                    node1_list{edge_cnt} = node_name_array{h}{idx1};
                    node2_list{edge_cnt} = node_name_array{h+1}{idx2};                    
                    weight_list(edge_cnt) = weight;                    
                end
            end
        end                                    
end

 % phase3 : graph wrapping 
 for k = 1: length(node_name_array{H+1})
    edge_cnt = edge_cnt + 1;
    node1_list{edge_cnt} = node_name_array{H+1}{k};
    node2_list{edge_cnt} = 'xf';
    weight_list(edge_cnt)= 0.1;
end
 
Astar_G=Astar_G.addedge(node1_list,node2_list, (weight_list));
[path_idx,total_cost]=Astar_G.shortestpath('t0n1','xf','Method','auto');
%% Phase 8 : plotting the planned path of polyhedron 
figure
hold on 
show(map3)
axis vis3d off
idx_seq = [];
for pnt_idx = path_idx
    pnt_idx_convert=cell2mat(pnt_idx);
    idx_seq = [idx_seq str2num(pnt_idx_convert(4:end))];        
end   
idx_seq = idx_seq(2:end);

conv_hull = {};

waypoint_polygon_seq = {};
corridor_polygon_seq = {};


for h = 1:H    
%     subplot(2,2,h)
     if h == 1 
            plot3(tracker(1),tracker(2),tracker(3),'mo','MarkerFaceColor','m')
     end
     
%         hold on 
%         plot3(target1_xs,target1_ys,target1_zs,'r^-','LineWidth',2)
%        
%         plot3(target1_xs(h),target1_ys(h),target1_zs(h),'rs','LineWidth',3,'MarkerSize',10)
% 
%         plot3(target2_xs,target2_ys,target2_zs,'r^-','LineWidth',2)
%         
%         plot3(target2_xs(h),target2_ys(h),target2_zs(h),'rs','LineWidth',3,'MarkerSize',10)
% 
%         plot3(tracker(1),tracker(2),tracker(3),'mo','MarkerFaceColor','m')
     
     
    plotregion(-A_div{h}{idx_seq(h)} ,-b_div{h}{idx_seq(h)} ,[xl yl zl]',[xu yu zu]',[1,0,1],0);
    hold on
    % 2D version 
%     waypoint_polygon_seq{h}.A = A_div{h}{idx_seq(h)};
%     waypoint_polygon_seq{h}.b = b_div{h}{idx_seq(h)};
    
    % 3D version 
    waypoint_polygon_seq{h}.A = [A_div{h}{idx_seq(h)}];
    waypoint_polygon_seq{h}.b =[b_div{h}{idx_seq(h)}];
               
    if h ==1 
        vert1 = tracker';
    else
        vert1 = v_div{h-1}{idx_seq(h-1)};        
    end    
    vert2 = v_div{h}{idx_seq(h)};    
    vert = [vert1 ; vert2];       
    K = convhull(vert(:,1), vert(:,2),vert(:,3));    
    shp = alphaShape(vert2(:,1),vert2(:,2),vert2(:,3),2);
    plot(shp,'EdgeColor','m','FaceColor',[1 0 1],'FaceAlpha',0.5,'LineWidth',1)
    
    [A_corr,b_corr]=vert2con(vert(K,:));
    % corridor connecting each waypoint polygon 
    
%     corridor_polygon_seq{h}.A =[A_corr] ;
%     corridor_polygon_seq{h}.b = [b_corr]; 
    
    corridor_polygon_seq{h}.A =[A_corr ] ;
    corridor_polygon_seq{h}.b = b_corr;        
    axis([xl xu yl yu zl zu])
end

% save('polygon_seq','waypoint_polygon_seq','corridor_polygon_seq');

%% Phase 8-1: safe corridor generation 



%% Phase 9: generation of smooth path (currently, the convex hull is assumed to be collision free, additional modification required)

ts= [0 1 2 3 4];

X0 = [tracker];
Xdot0 = zeros(3,1);
Xddot0 = zeros(3,1);

% figure

% smooth path generation in the corrideor  (TODO)
w_wpnts =0; % weight for waypoint deriving 
[pxs,pys,pzs]=min_jerk_ineq(ts,X0,Xdot0,Xddot0,waypoint_polygon_seq,corridor_polygon_seq,w_wpnts);

% draw path 
for h = 1:H
%     subplot(2,2,h)
    hold on
    [xps, yps, zps]=plot_poly_spline(ts,reshape(pxs,[],1),reshape(pys,[],1),reshape(pzs,[],1),'c-');    
    axis equal
end


%% Phase 10: camera included 
% final result 
figure
% subplot(4,2,1:4)
% show(map3)
axis vis3d off
hold on 
plot3(target1_xs,target1_ys,target1_zs,'r^-','LineWidth',2)
plot3(target2_xs,target2_ys,target2_zs,'r^-','LineWidth',2)
plot3(tracker(1),tracker(2),2,'mo','MarkerFaceColor','m')
draw_box([xl yl zl],[xu yu zu],'k',0.)

% this is wrapping of the octomap voxels 
margin = 0.5*ones (1,3);

% for idx = 1:max(IDX)
%     draw_box(boxes{idx}.lower - margin,boxes{idx}.upper + margin,'k',0.6)
% end

show(map3)
axis([xl  xu yl yu zl zu])

[knot_x,knot_y, knot_z]=plot_poly_spline(ts,reshape(pxs,[],1),reshape(pys,[],1),reshape(pzs,[],1),'c-');  

% draw camera  
for i = 1: length(knot_x)-1
    camera_origin = [knot_x(i+1) knot_y(i+1) knot_z(i+1)];
   
    % body axis of camera
    
    v1 = [(-camera_origin(1)  + target1_xs(i)) (-camera_origin(2)  + target1_ys(i)) (-camera_origin(3)  + target1_zs(i)) ]'; % bearing vector to target1
    v2 = [(-camera_origin(1)  + target2_xs(i)) (-camera_origin(2)  + target2_ys(i)) (-camera_origin(3)  + target2_zs(i)) ]'; % bearing vector to target2

    % we pick the bearing point by equally dividing the angle of v1 and v2 
    
    target1 = [target1_xs(i) target1_ys(i) target1_zs(i)];
    target2 = [target2_xs(i) target2_ys(i) target2_zs(i)];
    seeing_pnt = (norm(v2)*target1 + norm(v1)*target2)/(norm(v1) + norm(v2));
    
    
    
%     % viewing the midpoint does not guarantee FOV constraint 
%     seeing_pnt  = [(target1_xs(i) + target2_xs(i))/2 ...
%         (target1_ys(i) + target2_ys(i))/2 ...
%         (target1_zs(i) + target2_zs(i))/2 ];
%     
    
    
    xb = seeing_pnt - camera_origin;
    xb = xb'/norm(xb); % 3 x 1 
    
    pan = atan2(xb(2),xb(1));
    tilt = atan2(xb(3),sqrt(xb(1)^2 + xb(2)^2));
    
    h=0.5;
    
    camera_R = eul2rotm([pan -tilt 0]);    
    plot_camera(camera_origin,camera_R,FOV,h,1)
    
    
    % draw the projection of target1 
    plot3([camera_origin(1) target1_xs(i)],[camera_origin(2) target1_ys(i)],[camera_origin(3) target1_zs(i)],'r-')

    t1 = (norm(xb)^2 * h )/(xb' * v1);
    proj_img_plane = camera_origin' + t1 * v1;
    plot3(proj_img_plane(1),proj_img_plane(2),proj_img_plane(3),'r*')

    
    % draw the projection of target2 
    plot3([camera_origin(1) target2_xs(i)],[camera_origin(2) target2_ys(i)],[camera_origin(3) target2_zs(i)],'r-')

    t2 = (norm(xb)^2 * h )/(xb' * v2);
    proj_img_plane = camera_origin' + t2 * v2;
    plot3(proj_img_plane(1),proj_img_plane(2),proj_img_plane(3),'r*')

end
axis([xl  xu yl yu zl zu])

axis equal








