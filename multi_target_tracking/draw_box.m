function draw_box(p1,p2,color_str,alpha)

 x=([0 1 1 0 0 0;1 1 0 0 1 1;1 1 0 0 1 1;0 1 1 0 0 0])*(p2(1)-p1(1))+p1(1); 
 y=([0 0 1 1 0 0;0 1 1 0 0 0;0 1 1 0 1 1;0 0 1 1 1 1])*(p2(2)-p1(2))+p1(2);
 z=([0 0 0 0 0 1;0 0 0 0 0 1;1 1 1 1 0 1;1 1 1 1 0 1])*(p2(3)-p1(3))+p1(3);
 
 x = R * x;
 y = R * y;
 z = R * z;
 
for i=1:6
 h=patch(x(:,i),y(:,i),z(:,i),color_str,'FaceAlpha',alpha);
 set(h,'edgecolor',[0 0 0],'EdgeAlpha',0.1)
end



end