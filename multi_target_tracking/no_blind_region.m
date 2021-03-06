function [A_blind_div,b_blind_div,A_blind,b_blind] = no_blind_region(target1,target2,FOV)
    % this function finds the 16 no blind region subdivided by the blind
    % box 
    % As,bs is 16 no blind region / A_blind / b_blind is enclosing
    % rectangle 

    rel_dist =norm(target1 - target2); % distance between the targets  2D plane assumed 
    blind_height = rel_dist/2/tan(FOV/2);

    rotz90 = [0 -1 0 ; 1 0 0 ; 0 0 1];

    vx = target2 - target1; vx = vx/norm(vx);
    vy = rotz90 * vx;
    vz = cross(vx,vy);

    lx = rel_dist;
    ly = 2*blind_height;
    lz = 2*blind_height;
    center = (target1 + target2)/2;
    corners = center +[vx*lx vy*ly vz*lz]/2 * [ 1 -1 -1 1 1 -1 -1 1 ; 1 1 -1 -1 1 1 -1 -1 ; 1 1 1 1 -1 -1 -1 -1];


    A = [vx' ; vy' ;-vx' ; -vy' ; vz' ; -vz']; % this is inward affine 
    xs = corners(:,[1 2 3 4 1 5]); % points sequence matched with the normal surface vectors 
    b= diag(A*xs);

    A_blind = A; b_blind = b; 
    
    % let''s find the 8 outwardly divided regions 

    A_out = -A; % outward affine 
    b_out = -b;
    affine_aug = [A_out b];

    % sign = +1 for outward / -1 for inward
    surf_select = {[1 2 5],[1 2 3 5],[2 3 5],[2 3 4 5],[3 4 5],[1 3 4 5],[1 4 5],[1 2 4 5] , ... % 1st floor 
        [1 2 5],[1 2 3 5],[2 3 5],[2 3 4 5],[3 4 5],[1 3 4 5],[1 4 5],[1 2 4 5],[1 2 3 4 5]}; % 2nd floor

    surf_direction = {[1 1 -1],[-1 1 -1 -1],[1 1 -1],[-1 1 -1 -1],[1 1 -1],[-1 -1 1 -1],[1 1 -1],[1 -1 -1 -1],... % 1st floor
         [1 1 1],[-1 1 -1 1],[1 1 1],[-1 1 -1 1],[1 1 1],[-1 -1 1 1],[1 1 1],[1 -1 -1 1],[-1 -1 -1 -1 1]}; % 2nd floor 

     % the 16 divided regions
     A_blind_div = {};
     b_blind_div = {};
    
     for idx = 1:17
         A_blind_div{idx} = surf_direction{idx}' .* A_out(surf_select{idx},:);
         b_blind_div{idx} = surf_direction{idx}'.* b_out(surf_select{idx});         
%          [~,~,flag]=linprog([],A_blind_div{idx},b_blind_div{idx});
%          
%          if(flag == -2)
%             warning('infeasible space in blind division')
%          end
         
    end


    


    


end