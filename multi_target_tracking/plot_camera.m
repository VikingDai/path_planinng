function plot_camera(p,R,FOV,h,LineWidth,draw_ground_proj)
    % this draw camera (pin hole model)
    % p : origin of camera / R : 3x3 rotation matrix / FOV : field of view
    % / h : camera illustrate - length of the center axis of the pin hole
    % model 
    % so / let's start with the original points {frame 1}
    
    p = reshape(p,3,1);
    T01 = [R  p ; [ 0 0 0 1] ];
    
    ly = h * tan(FOV/2);
    lz = ly; 
        
    pnt0 = [0 0 0];
    pnt1 = [h ly lz];
    pnt2 = [h -ly lz];
    pnt3 = [h -ly -lz];
    pnt4 = [h ly -lz];
    
    pnts = [pnt0 ; pnt1 ; pnt2; pnt3; pnt4];
    
    pnts = [pnts' ; ones(1,size(pnts,1))];
    
    pnts_real = T01 * pnts;
    pnts_real = pnts_real(1:3,:)';
    hold on 
    % four leading edge 
    proj_pnts = [];
    for i = 1:4 
        plot3([pnts_real(1,1) pnts_real(i+1,1)],[pnts_real(1,2) pnts_real(i+1,2)],[pnts_real(1,3) pnts_real(i+1,3)],'k-','LineWidth',LineWidth)
        v = -pnts_real(1,:) + pnts_real(i+1,:);
        

                
    end
    
    % the bottom box 
    plot3([pnts_real(2,1) pnts_real(3,1)],[pnts_real(2,2) pnts_real(3,2)],[pnts_real(2,3) pnts_real(3,3)],'k-','LineWidth',LineWidth)
    plot3([pnts_real(3,1) pnts_real(4,1)],[pnts_real(3,2) pnts_real(4,2)],[pnts_real(3,3) pnts_real(4,3)],'k-','LineWidth',LineWidth)
    plot3([pnts_real(4,1) pnts_real(5,1)],[pnts_real(4,2) pnts_real(5,2)],[pnts_real(4,3) pnts_real(5,3)],'k-','LineWidth',LineWidth)
    plot3([pnts_real(5,1) pnts_real(2,1)],[pnts_real(5,2) pnts_real(2,2)],[pnts_real(5,3) pnts_real(2,3)],'k-','LineWidth',LineWidth)
    
%     % if ground projection is turned on 
%     if draw_ground_proj
%         patch(proj_pnts(:,1),proj_pnts(:,2),proj_pnts(:,3),'y','FaceAlpha',0.3)        
%     end
    
    
    
    
    
     
    
    
    
    
    
    
    
    
    
    
    


end