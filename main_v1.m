%% Load subject data 
% According to guide/recitation 

session = IEEGSession('I521_Sub1_Training_ecog', 'bkarpowicz3', 'bka_ieeglogin.bin');
ecog1 = session.data(1).getvalues(1:300000, 1:62);
session = IEEGSession('I521_Sub1_Training_dg', 'bkarpowicz3', 'bka_ieeglogin.bin');
glove1 = session.data(1).getvalues(1:300000, 1:5);
session = IEEGSession('I521_Sub1_Leaderboard_ecog', 'bkarpowicz3', 'bka_ieeglogin.bin');
test1 = session.data(1).getvalues(1:147500, 1:62);

sR = session.data.sampleRate;

session = IEEGSession('I521_Sub2_Training_ecog', 'bkarpowicz3', 'bka_ieeglogin.bin');
ecog2 = session.data(1).getvalues(1:300000, 1:48);
session = IEEGSession('I521_Sub2_Training_dg', 'bkarpowicz3', 'bka_ieeglogin.bin');
glove2 = session.data(1).getvalues(1:300000, 1:5);
session = IEEGSession('I521_Sub2_Leaderboard_ecog', 'bkarpowicz3', 'bka_ieeglogin.bin');
test2 = session.data(1).getvalues(1:147500, 1:48);

session = IEEGSession('I521_Sub3_Training_ecog', 'bkarpowicz3', 'bka_ieeglogin.bin');
ecog3 = session.data(1).getvalues(1:300000, 1:64);
session = IEEGSession('I521_Sub3_Training_dg', 'bkarpowicz3', 'bka_ieeglogin.bin');
glove3 = session.data(1).getvalues(1:300000, 1:5);
session = IEEGSession('I521_Sub3_Leaderboard_ecog', 'bkarpowicz3', 'bka_ieeglogin.bin');
test3 = session.data(1).getvalues(1:147500, 1:64);

%% Extract Features 

feat1 = extractFeatures_v1(ecog1, sR);
feat2 = extractFeatures_v1(ecog2, sR);
feat3 = extractFeatures_v1(ecog3, sR);

save('features.mat', 'feat1', 'feat2', 'feat3');

%% Downsample glove data 
% Need to bring samples down to every 50ms to align with features.

glove1_down = [];
glove2_down = [];
glove3_down = [];
for i = 1:5
    glove1_down(:, end+1) = decimate(glove1(:, i), 50);
    glove2_down(:, end+1) = decimate(glove2(:, i), 50);
    glove3_down(:, end+1) = decimate(glove3(:, i), 50);
end 

glove1_down = glove1_down(1:end-1, :);
glove2_down = glove2_down(1:end-1, :);
glove3_down = glove3_down(1:end-1, :);

%% Linear Regression 

Y1 = linreg(feat1, glove1_down, feat1);
Y2 = linreg(feat2, glove2_down, feat2);
Y3 = linreg(feat3, glove3_down, feat3);

%% Cubic Interpolation of Results 
% Bring data from every 50ms back to 1000 Hz. 

up1 = [];
up2 = [];
up3 = [];

for i = 1:5
    up1(:, i) = spline(1:size(Y1, 1), Y1(:, i), 1:1/50:size(Y1, 1)); %off by 1 problem?? should be 1/50
    up2(:,i) = spline(1:size(Y2, 1), Y2(:,i), 1:1/50:size(Y2, 1));
    up3(:,i) = spline(1:size(Y3, 1), Y3(:,i), 1:1/50:size(Y3, 1));
end 

%% Zero pad upsampled 

up1 = [zeros(150, 5); up1; zeros(49, 5)];   % pad equivalent of 2 windows in the beginning
up2 = [zeros(150, 5); up2; zeros(49, 5)];
up3 = [zeros(150, 5); up3; zeros(49, 5)];

%% Visualize prediction of train data 

figure();
plot(up1(:, 1));
hold on;
plot(glove1(:, 1)); 

% this looks quite bad

%% Calculate correlation

corr1 = zeros(1, 5);
corr2 = zeros(1, 5);
corr3 = zeros(1, 5);
for i = 1:5             % iterate over fingers
    corr1(i) = corr(glove1(:, i), up1(:, i));
    corr2(i) = corr(glove2(:, i), up2(:, i));
    corr3(i) = corr(glove3(:, i), up3(:, i));
end

avgcorr1 = mean(corr1)
avgcorr2 = mean(corr2)
avgcorr3 = mean(corr3)

%% Cross Validation

rng default

numfold = 10;   % number of folds

ind = (size(glove1_down, 1)-mod(size(glove1_down, 1), numfold));    % truncate data to even #
ind = 1:ind;
numelem = length(ind)/numfold;    % # elements per fold
folds = cell(1, numfold);
for i = 0:length(folds)-1
    folds{i+1} = ind((i*numelem+1):((i+1)*numelem));
end

ind = 1:300000;     % fold indices for 1000 Hz data
numelem = length(ind)/numfold;    % # elements per fold
foldsfull = cell(1, numfold);
for i = 0:length(foldsfull)-1
    foldsfull{i+1} = ind((i*numelem+1):((i+1)*numelem));
end

% calculate validation error for each fold
crosscorr1 = zeros(numfold, 5);
crosscorr2 = zeros(numfold, 5);
crosscorr3 = zeros(numfold, 5);
for i = 1:length(folds)     % fold that is testing set
    trainfold1 = [];
    fingers1 = [];
    trainfold2 = [];
    fingers2 = [];
    trainfold3 = [];
    fingers3 = [];

    % accumulate training data
    for j = 1:length(folds)
        if i ~= j
            trainfold1 = [trainfold1; feat1(folds{j}, :)];
            fingers1 = [fingers1; glove1_down(folds{j}, :)];
            
            trainfold2 = [trainfold2; feat2(folds{j}, :)];
            fingers2 = [fingers2; glove2_down(folds{j}, :)];
            
            trainfold3 = [trainfold3; feat3(folds{j}, :)];
            fingers3 = [fingers3; glove3_down(folds{j}, :)];
        end
    end
    
    % train model
    Y1 = linreg(trainfold1, fingers1, feat1(folds{i}, :));
    Y2 = linreg(trainfold2, fingers2, feat2(folds{i}, :));
    Y3 = linreg(trainfold3, fingers3, feat3(folds{i}, :));
    
    up1 = [];
    up2 = [];
    up3 = [];
    
    for l = 1:5
        up1(:, l) = spline(1:size(Y1, 1), Y1(:, l), 1:1/50:size(Y1, 1)); %off by 1 problem?? should be 1/50
        up2(:, l) = spline(1:size(Y2, 1), Y2(:, l), 1:1/50:size(Y2, 1));
        up3(:, l) = spline(1:size(Y3, 1), Y3(:, l), 1:1/50:size(Y3, 1));
    end
    
    up1 = [zeros(150, 5); up1; zeros(49, 5)];   % pad equivalent of 2 windows in the beginning
    up2 = [zeros(150, 5); up2; zeros(49, 5)];
    up3 = [zeros(150, 5); up3; zeros(49, 5)];
    
    testlabel1 = glove1(foldsfull{i}, :);
    testlabel2 = glove2(foldsfull{i}, :);
    testlabel3 = glove3(foldsfull{i}, :);
    for k = 1:5
        crosscorr1(i, k) = corr(testlabel1(:, k), up1(:, k));
        crosscorr2(i, k) = corr(testlabel2(:, k), up2(:, k));
        crosscorr3(i, k) = corr(testlabel3(:, k), up3(:, k));
    end
end

avgcorr1 = mean(crosscorr1)
avgcorr2 = mean(crosscorr2)
avgcorr3 = mean(crosscorr3)

totalcorr = [avgcorr1([1, 2, 3, 5]), avgcorr2([1, 2, 3, 5]), avgcorr3([1, 2, 3, 5])];
avgcorr = mean(totalcorr)

%% Testing extract features

testfeat1 = extractFeatures_v1(test1, sR);
testfeat2 = extractFeatures_v1(test2, sR);
testfeat3 = extractFeatures_v1(test3, sR);

save('testfeatures.mat', 'testfeat1', 'testfeat2', 'testfeat3');

%%

testpred1 = linreg(feat1, glove1_down, testfeat1);
testpred2 = linreg(feat2, glove2_down, testfeat2);
testpred3 = linreg(feat3, glove2_down, testfeat3);

testup1 = [];
testup2 = [];
testup3 = [];

for i = 1:5
    testup1(:, i) = spline(1:size(testpred1, 1), testpred1(:, i), 1:1/50:size(testpred1, 1)); %off by 1 problem?? should be 1/50
    testup2(:, i) = spline(1:size(testpred2, 1), testpred2(:, i), 1:1/50:size(testpred2, 1));
    testup3(:, i) = spline(1:size(testpred3, 1), testpred3(:, i), 1:1/50:size(testpred3, 1));
end 

testup1 = [zeros(150, 5); testup1; zeros(49, 5)];
testup2 = [zeros(150, 5); testup2; zeros(49, 5)];
testup3 = [zeros(150, 5); testup3; zeros(49, 5)];

predicted_dg = cell(1, 3);
predicted_dg{1} = testup1(1:147500, 1:5);
predicted_dg{2} = testup2(1:147500, 1:5);
predicted_dg{3} = testup3(1:147500, 1:5);

save('checkpoint1.mat', 'predicted_dg');
