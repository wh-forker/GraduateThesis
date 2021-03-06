%Achieve a space-time MRF model to detect the anomaly
%author: tong 2013/3/31-2013/4/31

clear all;

%read the test video from UNM video dataset
source = VideoReader('E:\Resources\vision_data\UMN Dataset\Crowd-Activity-All.AVI'); %读入原始视频
frame_len = source.NumberOfFrames;

%%build the spatio-Temporal MRF model by the original 10 frames
spMRF_size = 10;%use the initial 10 frames train the sp-MRF model
spMRF_features = cell(spMRF_size, 1);
pre_frame = read(source, 1);%读取第1帧
frame_size = size(pre_frame);%row:240 col:320
region_size = 40; %40*40
subregion_size = 20; %20*20
subregion_num = region_size/subregion_size;
mlen = frame_size(1)/region_size;
nlen = frame_size(2)/region_size;
pre_frame = rgb2gray(pre_frame);
for i=2:spMRF_size+1
    cur_frame = read(source, i);%读取帧
    cur_frame = rgb2gray(cur_frame);
    
    %%compute the features of optical flow by LK method
    %divide each frame to m*n regions and every region is also divided to u*v small sub-regions
    %compute the 9 dimension vector descriptor (8 orientations + 1 speed)
    %finally get 9uv dimension vector of each region(node)
    [Vx,Vy] = opticalFlow(pre_frame,cur_frame,'smooth',1,'radius',10,'type','LK');%use piotr_toolbox
    %show the visual result
%     figure
%     axis equal
%     quiver(impyramid(medfilt2(flipud(Vx), [5 5]), 'reduce'), -impyramid(medfilt2(flipud(Vy), [5 5]), 'reduce'));
    %划分出8个区域 分别对8个区域内点进行向量求和
%     [oreintation] = atan(Vy./Vx);%compute the orientation
%     [degree] = oreintation.*180/pi;%convert to degree
%     negIndex = find(Vx<0);%find the index of negtive elements in Vx for correct the degree in 2 or 3 quadrant(象限)
%     degree(negIndex) = degree(negIndex) + 180;
%     degree(:) = mod((degree(:)+360), 360);%change to 0-360 degree
    [speed] = sqrt(Vx.*Vx+Vy.*Vy);%compute the speed    
    mrf_features = cell(mlen, nlen);
    for m=1:mlen
        for n=1:nlen
            %divide into regions 30*40
            rowbegin = (m-1)*region_size+1;rowend = m*region_size;
            colbegin = (n-1)*region_size+1;colend = n*region_size;
            [regionVx] = Vx(rowbegin:rowend, colbegin:colend);
            [regionVy] = Vy(rowbegin:rowend, colbegin:colend);
            [regionSpeed] = speed(rowbegin:rowend, colbegin:colend);
            
            nodeFeatures = cell(subregion_num,subregion_num);
            %divide into 4 sub-regions 20*20
            for u=1:subregion_num
                for v=1:subregion_num
                    rbegin = (u-1)*subregion_size+rowbegin;
                    cbegin = (v-1)*subregion_size+colbegin;
                    [subregionVx] = Vx(rbegin:rbegin+subregion_size-1, cbegin:cbegin+subregion_size-1);
                    [subregionVy] = Vy(rbegin:rbegin+subregion_size-1, cbegin:cbegin+subregion_size-1);
                    [subregionSpeed] = speed(rbegin:rbegin+subregion_size-1, cbegin:cbegin+subregion_size-1);
                    
                    speedSum = sum(subregionSpeed(:));%compute the sum of speed in sub-region
                    %divide sub-region into 8 patitions
                    quadrant = cell(2, 8);
                    %Vx
                    [quadrant1x]=subregionVx(1:10, 11:20);%partition 0-90 degree , first quadrant
                    quadrant{1,1} = tril(fliplr(quadrant1x));%次对角线的下三角 需先进行翻转
                    quadrant{1,2} = triu(fliplr(quadrant1x));%次对角线的上三角 需先进行翻转                 
                    [quadrant2x]=subregionVx(1:10, 1:10);%partition 90-180 degree , second quadrant
                    quadrant{1,3} = triu(quadrant2x);%主对角线的上三角
                    quadrant{1,4} = tril(quadrant2x);%主对角线的下三角
                    [quadrant3x]=subregionVx(11:20, 1:10);%partition 180-270 degree , third quadrant
                    quadrant{1,5} = triu(fliplr(quadrant3x));%次对角线的上三角 需先进行翻转
                    quadrant{1,6} = tril(fliplr(quadrant3x));%次对角线的下三角
                    [quadrant4x]=subregionVx(11:20, 11:20);%partition 270-360 degree , fourth quadrant
                    quadrant{1,7} = tril(quadrant4x);
                    quadrant{1,8} = triu(quadrant4x);
                    %Vy
                    [quadrant1y]=subregionVy(1:10, 11:20);%partition 0-90 degree , first quadrant
                    quadrant{2,1} = tril(fliplr(quadrant1y));%次对角线的下三角 需先进行翻转
                    quadrant{2,2} = triu(fliplr(quadrant1y));%次对角线的上三角 需先进行翻转                   
                    [quadrant2y]=subregionVy(1:10, 1:10);%partition 90-180 degree , second quadrant
                    quadrant{2,3} = triu(quadrant2y);%主对角线的上三角
                    quadrant{2,4} = tril(quadrant2y);%主对角线的下三角
                    [quadrant3y]=subregionVy(11:20, 1:10);%partition 180-270 degree , third quadrant
                    quadrant{2,5} = triu(fliplr(quadrant3y));%次对角线的上三角 需先进行翻转
                    quadrant{2,6} = tril(fliplr(quadrant3y));%次对角线的下三角
                    [quadrant4y]=subregionVy(11:20, 11:20);%partition 270-360 degree , fourth quadrant
                    quadrant{2,7} = tril(quadrant4y);
                    quadrant{2,8} = triu(quadrant4y);
                    
                    [oreintations] = zeros(1,8);
                    %求8个划分的向量和
                    for k=1:8
                        vectorY = sum(quadrant{2,k}(:));
                        vectorX = sum(quadrant{1,k}(:));
                        degree = atan(vectorY/vectorX);%compute the orientation
                        angle = degree.*180/pi;%convert to angle 得到的是-90到90度之间的值
                        if (vectorX<0) %2 3 象限
                            angle = angle +180;
                        end
                        if (vectorX>0 && vectorY<0) % 4象限
                            angle = angle +360;
                        end
                        oreintations(k) = angle;
                    end
                    nodeFeatures{u,v} = [speedSum, oreintations];
                end
            end
            
            mrf_features{m,n} = [nodeFeatures{1,1},nodeFeatures{1,2},nodeFeatures{2,1},nodeFeatures{2,2}];
        end
    end    
    
    spMRF_features{i-1,1} = mrf_features;
    %%end fo computing features
    
    pre_frame=cur_frame;%update the pre_frame
end

%%train the local learning pattern by mixture ppca
%compute two histograms: frequency histogram frq_hist and co-occurrence histogram co_hist
mppcaPattern = cell(mlen, nlen);
for i=1:mlen
    for j=1:nlen
        cohist;
        frqtemp = 0;
        for k=1:10
            mrf_features = spMRF_features{k,1};
            frqtemp = frqtemp;
        end
        mppcaPattern{i,j}.frqhist = 
    end
end    

%how to compute the posteriors

%%end of creating learning pattern



%create the space-time MRF and inference by BP(Bayesian Belief Propogation)


%sign the abnormal regions 