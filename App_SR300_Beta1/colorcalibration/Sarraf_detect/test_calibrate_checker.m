% this function takes as input a Macbeth checker img and 
% returns a 3x3 transformation matrix. This matrix color calibrates 
% other images taken under the same light conditions (ideally same session)
% as the checkerboard picture used.



    
    figure('Name',img_char);
    imshow(I1)
    title(img_char);



function M = calibrate_checker(check_from_cam)
    %each begining of a 6-patch line on the checker is represented 
    % in the comments of RGB_ref as  ----------- 
    RGB_ref =  [115     82     68; %(1,:)dark skin (brown) ----------- 
                194    150    130; %    light skin
                 98    122    157; %    blue sky
                 87    108     67; %    foliage
                133    128    177; %    blue flower
                103    189    170; %(6,:)bluish green
                214    126     44; %(7,:)organge -----------
                 80     91    166;
                193     90     99;
                 94     60    108;
                157    188     64; 
                224    163     46; %(12,:)orange yellow
                 56     61    150; %(13,:)blue -----------
                 70    148     73;
                175     54     60;
                231    199     31;
                187     86    149; 
                  8    133    161; %(18,:)cyan
                243    243    242; %%(19,:)white-----------
                200    200    200;
                160    160    160;
                122    122    121;
                 85     85     85; 
                 52     52     52];%(24,:)black

             
    
    
    
    
    
    
             
    
end

% function ColorPatchDetectClean written by Dr. Hamed Sari-Sarraf, 
% professor at Texas Tech University
% summer 2018
function [colorPos, checker_found, error] = ColorPatchDetectClean(RGB_img)
    addpath(pwd);
    
    error = MException.empty();
    checker_found = 0;
    colorPos = 0;
    close all
    try 
        if size(RGB_img,1)/size(RGB_img,2) > .68...
           && size(RGB_img,1)/size(RGB_img,2) < .8
            RGB_img = imresize(RGB_img,[480 640]);
        else
            disp('use 4x3 images (e.g 640x480)')
            return;
        end
        
        %homogeneous grayscale
        I1=rgb2hsv(RGB_img);
        I1=I1(:,:,3);
        %constrain in number of pixels
        [regions]=detectMSERFeatures(I1,'RegionAreaRange',[1000 10000]);
        %majorAxis / minorAxis; if <= 0.9 it's too distorted to be a circle
        circular=(regions.Axes(:,2)./regions.Axes(:,1))>0.9;
        %assigning empty values to regions that are not circles
        regions(circular==0)=[];
        %each PixelList has all the pixels of a region, with their location
        %cell {pixelNum, [x y]}
        tar_reg=cell2mat(regions.PixelList);
        
        if isempty(tar_reg)%checker wasn't found
            disp('Failed to detect checkerboard');
           return 
        end
        %new black and white image
        BW=zeros(size(I1));
        % tar_reg(:,2) == y from regions'  pixel list
        % tar_reg(:,1) == x from regions' pixel list
        % sub2ind finds linear index within img
        BW(sub2ind(size(I1),tar_reg(:,2),tar_reg(:,1)))=1;
        %figure('Name',img_char);
        %binary img with regions of interest in white
        % [] scales pixel intensity to 
        % black for min and white to max
        imshow(BW,[]);
        %title(img_char);
        %T3 is non-singular (det non-zero)
        T3=[1 0 0; 0 1 0; -5 -5 1];
        %sets of parallel lines remain parallet after affine transform
        tform = affine2d(T3);
        % Nearest-neighbor interpolation?the output pixel is assigned the value 
        % of the pixel that the point falls within. No other pixels are considered.
        BW=imwarp(BW,tform,'nearest','outputview',imref2d(size(BW)));
        BW=imclearborder(BW,8);
        T3=[1 0 0; 0 1 0; 10 10 1];
        tform = affine2d(T3);
        BW=imwarp(BW,tform,'nearest','outputview',imref2d(size(BW)));
        %clears small/noise components (such as text)
        BW=imclearborder(BW,8);
        T3=[1 0 0; 0 1 0; -5 -5 1];
        tform = affine2d(T3);
        BW=imwarp(BW,tform,'nearest','outputview',imref2d(size(BW)));

        %LABELS (with increasing nums > 0 ) all the objects found in the B&W pic
        L=bwlabel(BW);

        stats = regionprops('table',L,'Centroid','Area');
        %logical array for areas 3 std dev greater or smaller than the mean obj areas
        sizefilt=stats.Area>(mean(stats.Area)+3*std(stats.Area)) | ...
            stats.Area<mean(stats.Area)-3*std(stats.Area);
        %if sizefilt not empty, assign 0 to pixels within areas 
        %beyond constrain
%         if ~isempty(find(sizefilt))
%            BW( L == find(sizefilt) )=0;
%         end
        if any(find(sizefilt))
           BW( L == find(sizefilt) )=0;
        end
        %gets the different regions again, now without outliers
        stats = regionprops('table',bwlabel(BW),'Centroid');
        figure
        imshow(BW,[]);
        %title(img_char);
        %L is a numerical labels matrix
        % B is a list of objects cell array 
            % each of its indexes is a list of pixels that form
            % the boundary of an individual object
        [B,L] = bwboundaries(BW,'noholes');
        figure
        %plots different colors for each diff. object
        imshow(label2rgb(L, @jet, [.5 .5 .5]))
        %title(img_char);
        hold on
        bou=zeros(size(I1));
        for k = 1:length(B)
           boundary = B{k};
           plot(boundary(:,2), boundary(:,1), 'w', 'LineWidth', 2)
           %draws obj boundaries on the new img
           bou(sub2ind(size(I1),floor(boundary(:,1)),floor(boundary(:,2))))=1;
        end
        % hough uses parametric representation of a line
        % 	: rho = x*cos(theta) + y*sin(theta).
        % 	 R(rho): distance from the origin to the line along 
        %		a vector perpendicular to the line
        %	 T(theta): angle in degrees between the x-axis and this vector.
        %    H(Standard Hough Transform): parameter space matrix whose rows 
        %		and columns correspond to rho and theta values respectively.
        %		and columns correspond to rho and theta values respectively.

        % NOTE FROM Mathworks: 
        % When you create the Hough transform matrix using the 
        % hough function, you must use the default theta value, [-90 90). 
        % Using a Hough transform matrix created with any other theta 
        % can produce unexpected results.

        [H,T,R] = hough(bou,'Theta',-45:45);
        %[H,T,R] = hough(bou,'Theta',-30:30);
        
        P  = houghpeaks(H,1);
        %finds angle for Hough peak line and the y value of the x-axis vector
        rotang = T(P(:,2)); 
        %finds distance  for Hough peak line from the origin of its x value of the x-axis vector
        rho = R(P(:,1));

        plot(rotang,rho,'s','color','white');
        % figure
        % imshow(imrotate(I1,rotang),[])
        %% 
        % imrotate(bou,rotang,'nearest','crop'): 2x2 nearest neighboor interpol.
        %   rotang: angle for better horizontal alingment
        %   bou: img with drawn (binary) boundaries
        % 	crop: same size as original img
        Sfft=abs(fftshift(fft2(imrotate(bou,rotang,'nearest','crop'))));
        
        % figure
        % imshow(Sfft,[])

        %this is just a (white) line
        win=Sfft(480/2,640/2+1-15:640/2+1+15);
        % 5 black pixels
        win(16-2:16+2)=0;
        %gets index of  white pixels
        [m,ind]=max(win(:));
        %index from subscripts
        [x,y]=ind2sub([1,31],ind);

        fff_r=abs(16-y);
        win=Sfft(480/2+1-15:480/2+1+15,640/2+1+fff_r);
        %win=Sfft(480/2+1-15:480/2+1+15,640/2+1);
        
        win(16-2:16+2)=0;
        [m,ind]=max(win(:));
        [x,y]=ind2sub([31,1],ind);
        fff_c=abs(16-x);

        mask=uint8(zeros(size(I1)));

        figure
        imshow(BW,[]);
        %title(img_char);
        hold on
        plot(stats.Centroid(:,1),stats.Centroid(:,2),'r*')
        % makes centroids' locations white on mask
        mask(sub2ind(size(I1),floor(stats.Centroid(:,2)),...
            floor(stats.Centroid(:,1))))=255;

        BW1=imrotate(BW,rotang,'nearest','crop');
        %selects regions related to labels (so really the patches themselves)
        stats1 = regionprops('table', bwlabel(BW1),'PixelList');
        xxx=cell2mat(stats1.PixelList);
        xmin=min(xxx(:,1));
        xmax=max(xxx(:,1));
        ymin=min(xxx(:,2));
        ymax=max(xxx(:,2));
        %counterclockwise rotation matrix based
        Rmat=[cosd(rotang) -sind(rotang); sind(rotang) cosd(rotang)];
        %clockwise rotation matrix
        iRmat=[cosd(rotang) sind(rotang); -sind(rotang) cosd(rotang)];

        %correctingn alingment of centroids
        C=[stats.Centroid(:,1)-640/2 stats.Centroid(:,2)-480/2]*Rmat;
        C=[C(:,1)+640/2 C(:,2)+480/2];

        % getting bottom borders
        Cnew1=[C(:,1) C(:,2)+480/fff_c];
        Cnew1(Cnew1(:,1)>xmax | Cnew1(:,1)<xmin,:)=[];
        Cnew1(Cnew1(:,2)>ymax | Cnew1(:,2)<ymin,:)=[];
        Cnew1=[Cnew1(:,1)-640/2 Cnew1(:,2)-480/2]*iRmat;
        Cnew1=[Cnew1(:,1)+640/2 Cnew1(:,2)+480/2];
        plot(Cnew1(:,1),Cnew1(:,2),'gs')
        mask(sub2ind(size(I1),floor(Cnew1(:,2)),floor(Cnew1(:,1))))=255;

        % getting top borders
        Cnew2=[C(:,1) C(:,2)-480/fff_c];
        Cnew2(Cnew2(:,1)>xmax | Cnew2(:,1)<xmin,:)=[];
        Cnew2(Cnew2(:,2)>ymax | Cnew2(:,2)<ymin,:)=[];
        Cnew2=[Cnew2(:,1)-640/2 Cnew2(:,2)-480/2]*iRmat;
        Cnew2=[Cnew2(:,1)+640/2 Cnew2(:,2)+480/2];
        plot(Cnew2(:,1),Cnew2(:,2),'gs')
        mask(sub2ind(size(I1),floor(Cnew2(:,2)),floor(Cnew2(:,1))))=255;

        % getting centroids on 5 squares to the right
        Cnew3=[C(:,1)+640/fff_r C(:,2)];
        Cnew3(Cnew3(:,1)>xmax | Cnew3(:,1)<xmin,:)=[];
        Cnew3(Cnew3(:,2)>ymax | Cnew3(:,2)<ymin,:)=[];
        Cnew3=[Cnew3(:,1)-640/2 Cnew3(:,2)-480/2]*iRmat;
        Cnew3=[Cnew3(:,1)+640/2 Cnew3(:,2)+480/2];
        plot(Cnew3(:,1),Cnew3(:,2),'gs')
        mask(sub2ind(size(I1),floor(Cnew3(:,2)),floor(Cnew3(:,1))))=255;
        % getting centroids on 5 squares to the left
        Cnew4=[C(:,1)-640/fff_r C(:,2)];
        Cnew4(Cnew4(:,1)>xmax | Cnew4(:,1)<xmin,:)=[];
        Cnew4(Cnew4(:,2)>ymax | Cnew4(:,2)<ymin,:)=[];
        Cnew4=[Cnew4(:,1)-640/2 Cnew4(:,2)-480/2]*iRmat;
        Cnew4=[Cnew4(:,1)+640/2 Cnew4(:,2)+480/2];
        plot(Cnew4(:,1),Cnew4(:,2),'gs')
        mask(sub2ind(size(I1),floor(Cnew4(:,2)),floor(Cnew4(:,1))))=255;
        
        % vertical, horizontal patches' locations
        mask=imdilate(mask,strel('disk',10));
        
        patches_posProps = regionprops('table',imbinarize(mask),L,...
            'PixelList','Centroid');
        %x: patches_posProps.Centroid(:,1),
        %y: patches_posProps.Centroid(:,2)
        locations = round(patches_posProps.Centroid);
        
        %rgb1(locations(2,2),locations(2,1),:);
        cornersFound = findCorners(RGB_img, locations, patches_posProps.PixelList);
        
        figure
        imshow((0.8*RGB_img+0.2*mask),[]);
        hold on
        
%     cornersFound = [bluishGreen;
%                     black;
%                     brown;
%                     white];
        if cornersFound(4,:) == [0 0]
            xlabel('No white patch found. Plase try again')
        else
            scatter(cornersFound(4,1),cornersFound(4,2),'xb');
        end
        % colorPos matches sequence on pdf document
        % colorPos(1:6,:) == brown ("dark skin") to bluish green (1st row)
        % color_pos(7:12,:) == orange to orange yellow(2nd row)
        % color_pos(13:18,:) == blue to cyan(3rd row)
        % color_pos(19:24,:) == white to black (3rd row)
        colorPos = zeros(24,3);
        
        if cornersFound
            colorPos = findAllColors(cornersFound);
            scatter(colorPos(1:6,2), colorPos(1:6,1),'LineWidth',15);
            % bluish green
            scatter(colorPos(6,2), colorPos(6,1),'LineWidth',15);
            xlabel('bluish green');
            pause
            scatter(colorPos(7:12,2), colorPos(7:12,1),'LineWidth',15);
            % orange yellow
            scatter(colorPos(12,2), colorPos(12,1),'LineWidth',15);
            xlabel('orange yellow');
            pause

            scatter(colorPos(13:18,2), colorPos(13:18,1),'LineWidth',15);
            % cyan
            scatter(colorPos(18,2), colorPos(18,1),'LineWidth',15);
            xlabel('cyan');
            pause

            scatter(colorPos(19:24,2), colorPos(19:24,1),'LineWidth',15);
            % black
            scatter(colorPos(24,2), colorPos(24,1),'LineWidth',15);
            xlabel('black');
            pause
        else
            disp('failed to detect');
            return
        end
        hold off
        pause
        colorCalibrate(colorPos, RGB_img, ...
            1, '', 1);
        checker_found = 1;
    catch ME
       error =  ME
    end
        
end
% finds the corners from the detected patches
% written by Alexandre Soares
%   2018 summer
function cornersFound = findCorners(img, locations, pixelList)
    %corners are
    %x(1), y(1) bluish green
    %x(2), y(2) black
    %x(3), y(3) brown
    %x(4), y(4) white
    
    img = img*1.01;
    b = convhull(locations(:,1),locations(:,2));
    convHul = [locations(b,1) locations(b,2)];
    norm_colected = zeros(length(convHul),1);

    %% gets distances between components of the convex hull;
    % guaranteed to return corners (they are an integral part of the
    % 4-sided polygon that represents the patches (mostly a rectangle, but
    % sometimes a rhombus
    
    for i=1:length(convHul)
        %taking the distances between all the vertices of the covnex hull
        %and the i_th point
        norm_colected(:,i) = vecnorm(convHul - convHul(i,:),2,2);... 
        %max norm for each iteration + index
        [maxNorm, i_max] = max(norm_colected(:,i));
        %i_max is the index of the i_th point with relation to
        % i_MaxFina_l (distance between them is max
        max_norm_colected(i,:) = [i_max, maxNorm];
    end

    %% gets largest 2 distances between points
    %   runs twice at each point because there'll be to two distances 
    %   that are the same - from point 1 to point 2 and vice versa
    %   when the first max is eliminated, then points with max distance
    %   are sored
    
    %1st run
    %i_MaxFinal serves as index to normHul, 1st point (i_th point)
    [ maxfinal_1, i_MaxFina_l] = max(max_norm_colected(:,2));
    %i_MaxFinal2 serves as index to normHul, 2nd point
    i_MaxFinal_12 = max_norm_colected(i_MaxFina_l,1);
    % repeat operation, now without the previous max
    max_norm_colected(i_MaxFina_l,2) = 0;
    
    %2nd run on point 1,2 - final storage happens here
    %i_MaxFinal serves as index to normHul, 1st point (i_th point)
    [ maxfinal_1, i_MaxFina_l] = max(max_norm_colected(:,2));
    %i_MaxFinal2 serves as index to normHul, 2nd point
    i_MaxFinal_12 = max_norm_colected(i_MaxFina_l,1);
    %get corner coordinates
    corners = [ convHul(i_MaxFina_l,1), convHul(i_MaxFina_l,2);...
                convHul(i_MaxFinal_12,1), convHul(i_MaxFinal_12,2)];
    % repeat operation, now without the previous max
    max_norm_colected(i_MaxFina_l,2) = 0;
    
    %1st run on points 3,4
    [ ~, i_MaxFinal_2] = max(max_norm_colected(:,2));
    %i_MaxFinal2 serves as index to normHul, 2nd point
    i_MaxFinal_22 = max_norm_colected(i_MaxFinal_2,1);
    max_norm_colected(i_MaxFinal_2,2) = 0;
    
    %2nd run on points 3,4 (storage)
    [ ~, i_MaxFinal_2] = max(max_norm_colected(:,2));
    %i_MaxFinal2 serves as index to normHul, 2nd point
    i_MaxFinal_22 = max_norm_colected(i_MaxFinal_2,1);
%     max_norm_colected(i_MaxFinal_22,2) = 0
    max_norm_colected(i_MaxFinal_2,2) = 0;
    
    corners = [ corners; 
                convHul(i_MaxFinal_2,1),convHul(i_MaxFinal_2,2);...
                convHul(i_MaxFinal_22,1),convHul(i_MaxFinal_22,2)];
    
    white = zeros(1,2);
    i_white =0;
    avg_white = 0;
    for i=1:length(corners)
        scatter(corners(i,1),corners(i,2),'d','LineWidth',20);
        
        offset=-2:2;
        y = corners(i,2)+offset;
        x = corners(i,1)+offset;
        y1 = corners(i,2)-offset;
        x1 = corners(i,1)+offset;
        y2 = corners(i,2)+offset;
        x2 = corners(i,1)-offset;
        
        avgPix_R = mean(img(y,x,1));
        avgPix_G = mean(img(y,x,2));
        avgPix_B = mean(img(y,x,3));
        
        R = mean(avgPix_R);
        G = mean(avgPix_G);
        B = mean(avgPix_B);

        R_minus_B = mean(abs(avgPix_R - avgPix_B));
        R_minus_G = mean(abs(avgPix_R - avgPix_G));
        G_minus_B = mean(abs(avgPix_B - avgPix_G));

        avg_pixel = mean(avgPix_R + avgPix_G + avgPix_B)/3;
        diff_pix = (R_minus_B + G_minus_B  + R_minus_G )/3;
        
        [R, G, B]
        [R_minus_B, R_minus_G, G_minus_B]
        [avg_pixel, diff_pix]
        %avgs and differences gathered from experimental values
        %white first (largest values)
        %oneDiff_is_zero = ~(R_minus_B || R_minus_G || G_minus_B);
        max_diff = max([R_minus_B, R_minus_G, G_minus_B]);
        min_diff = min([R_minus_B, R_minus_G, G_minus_B]);
        
        
        maxRGB = max([R G B]);
        minRGB = min([R G B]);
        
        diff_betwMaxAdnMinDiff = maxRGB - minRGB;
        %diff_betwMaxAdnMinDiff = max_diff  - min_diff;
        
        % finds white
        if avg_pixel > 125 && diff_pix < 60
            if R_minus_B < 12 || R_minus_G  < 12 ...
                || G_minus_B  < 12                
                if ~isempty(white) && avg_white > 190
                    white = white;
                else
                    if diff_betwMaxAdnMinDiff < 20
                        avg_white = avg_pixel;
                        white = corners(i,:);
                        i_white = i;
                    end
                end
            end
            if R > 200 && B > 200 && G > 200
                if ~isempty(white) && avg_white > 200
                    white = white;
                else
                    if  diff_betwMaxAdnMinDiff < 50
                        avg_white = avg_pixel;
                        white = corners(i,:);
                        i_white = i;
                    end
                end
            end
        end
    end

    %% calculate distance from white to other corners
        % determines position of 4 specific colors: bluish green, black,
        % and brown
    if i_white %if white was found
        dist_whiteFromOthers = zeros(4,1);
        for i=1:4
            dist_whiteFromOthers(i) = vecnorm(corners(i_white,:) - corners(i,:),2,2);
        end
        
        %farthest corner from white is bluish green
        [~,indexDistMax] = max(dist_whiteFromOthers);
        bluishGreen = corners(indexDistMax,:);
        %eliminates bluish corner dsitance, so nex max is black
        dist_whiteFromOthers(indexDistMax) = 0; 
        
        %farthest corner from white is black now (bluish green == 0 now)
        [~,indexDistMax] = max(dist_whiteFromOthers);
        black = corners(indexDistMax,:);
        %eliminates bluish corner dsitance, so nex max is brown
        dist_whiteFromOthers(indexDistMax) = 0; %eliminates the opposing corner
        
        %farthest corner from white is brown now (black == 0 now)
        [~,indexDistMax] = max(dist_whiteFromOthers);
        brown = corners(indexDistMax,:);
        %eliminates bluish corner dsitance, so nex max is brown
        dist_whiteFromOthers(indexDistMax) = 0; %eliminates the opposing corner       

        cornersFound = [bluishGreen;
                        black;
                        brown;
                        white];
    else
        cornersFound = 0;
    end
end
% finds positions for all patches from 
% corners detected 
% written by Alexandre Soares da Silva
%   2018 summer
function colorPos = findAllColors(cornersFound)
%     %x(1), y(1) bluish green
%     %x(2), y(2) black
%     %x(3), y(3) brown
%     %x(4), y(4) white
%     cornersFound = [bluishGreen;
%                     black;
%                     brown;
%                     white];
    x =  cornersFound(:,1);
    y =  cornersFound(:,2);
    
%     [x(1), y(1)] =  cornersFound(1,:);
%     [x(2), y(2)] =  cornersFound(2,:);
%     [x(3), y(3)] =  cornersFound(3,:);
%     [x(4), y(4)] =  cornersFound(4,:);
    step_blgr_to_brwn = ([x(1), y(1)] - [x(3), y(3)])/5;
    %black to white
    step_bk_to_wh = ([x(2), y(2)] - [x(4), y(4)])/5;

    blgr_to_brw(1,:) = [x(1), y(1)];
    bk_to_wh(1,:) = [x(2), y(2)];
    for i=2:6 %for sides
       %bluish green to brown
       blgr_to_brw(i,:) = blgr_to_brw(i-1,:)- step_blgr_to_brwn;
       %black to white
       bk_to_wh(i,:) = bk_to_wh(i-1,:)- step_bk_to_wh;
    end
    %step size between the large sides
    step_btw_wideSide = (blgr_to_brw - bk_to_wh)/3;
    %% matrix that holds positions for all colors
    colors = {'ob','xw','xm','og'};
    % color_pos(:,:,1) == bluish green to brown ("dark skin") (1st row)
    % color_pos(:,:,2) == orange yellow to orange(2nd row)
    % color_pos(:,:,3) == cyan to blue(3rd row)
    % color_pos(:,:,4) == black 2 to white(3rd row)
    color_pos(:,:,1) = blgr_to_brw;
    for i=2:4 %for sides
       color_pos(:,:,i) = color_pos(:,:,i-1) - step_btw_wideSide;
       scatter(color_pos(:,1,i),color_pos(:,2,i),cell2mat(colors(i)))
    end
    
    colorPos = round(color_pos(end:-1:1,2:-1:1,1));
    % colorPos matches sequence on pdf document
    % colorPos(1:6,:) == brown ("dark skin") to bluish green (1st row)
    % color_pos(7:12,:) == orange to orange yellow(2nd row)
    % color_pos(13:18,:) == blue to cyan(3rd row)
    % color_pos(19:24,:) == white to black (3rd row)
    
    for i=2:4
        colorPos = [                colorPos; 
                    round(color_pos(end:-1:1,2:-1:1,i))];
    end
end