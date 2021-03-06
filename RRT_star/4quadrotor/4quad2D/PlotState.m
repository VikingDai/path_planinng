function PlotState(x,u,data)
    % This draws the 4quads and the load slung to it. 
    xl=x(1:3); %2
    vl=x(4:6); %2
    Rl=reshape(x(7:15),3,3);  %4
    wl=x(16:18);    %1 
    ri=data.ri;  %3x4 ri matrix 
    
    Q=reshape(u(1:12),3,4);
    % direction of tension
    for i=1:4
        Q(:,i) =Q(:,i)/norm(Q(:,i));
    end
    
    T=u(13:16);
    corners=SE3(Rl,xl)*ri;
    Tvec=Rl*Q.*repmat(T',3,1);  % tension vectors 3 x 4 
     
    DrawBox(SE3(Rl,xl),ri(:,1));
    hold on
    DrawAxis(SE3(Rl,xl),1);
    for i=1:4
        quiver3(corners(1,i),corners(2,i),corners(3,i),Tvec(1,i),Tvec(2,i),Tvec(3,i),'k','LineWidth',2);
    end
    
    hold off 

    
end