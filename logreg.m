%% Train logistic classifier
% Tip: run each logistic training in parallel or on different machines

%% Get raw data
load('4-27_features9.mat')
load('4-27_testfeatures9.mat')
load('raw_glove.mat')

%% Get features for all patients
sR = 1000; % Hz
numFeats = 6; % 6 features
feat1 = extractFeatures(ecog1, sR, numFeats); 
feat2 = extractFeatures(ecog2, sR, numFeats); 
feat3 = extractFeatures(ecog3, sR, numFeats); 

%% Logistic Regression: Create Labels
threshold1 = 1;
biglove1 = (glove1 > threshold1);
threshold2 = 0.8;
biglove2 = (glove2 > threshold2);
threshold3 = 0.6;
biglove3 = (glove3 > threshold3);

biglove1 = double(biglove1);
biglove2 = double(biglove2);
biglove3 = double(biglove3);

%%
% Average neighboring class 1 labels within 4s
neighborLen = 4*sR;
biglove = {biglove1, biglove2, biglove3};
for g = 1:3
    currglove = biglove{1, g};
    for finger = 1:5
        data = currglove(:, finger);
        newlabels = data;
        for i = 1:length(data) - neighborLen
            window = data(i:i+neighborLen);
            indices = find(window == 1);
            if length(indices) > 1
                window(indices(1):indices(end)) = ones(1, indices(end)-indices(1) + 1);
            end
            newlabels(i:i+neighborLen) = window;
        end
        currglove(:, finger) = newlabels;
    end
    biglove{1, g} = currglove;
end
disp('Finished logistic thresholding')

%% Visualize threshold over raw data
figure();
subplot(4,1,1)
plot(biglove{1}(:, 1))
hold on
plot(glove1(:, 1))
subplot(4,1,2)
plot(biglove{1}(:, 2))
hold on
plot(glove1(:, 2))
subplot(4,1,3)
plot(biglove{1}(:, 3))
hold on
plot(glove1(:, 3))
subplot(4,1,4)
plot(biglove{1}(:, 5))
hold on
plot(glove1(:, 5))

figure();
subplot(4,1,1)
plot(biglove{2}(:, 1))
hold on
plot(glove2(:, 1))
subplot(4,1,2)
plot(biglove{2}(:, 2))
hold on
plot(glove2(:, 2))
subplot(4,1,3)
plot(biglove{2}(:, 3))
hold on
plot(glove2(:, 3))
subplot(4,1,4)
plot(biglove{2}(:, 5))
hold on
plot(glove2(:, 5))

figure();
subplot(4,1,1)
plot(biglove{3}(:, 1))
hold on
plot(glove3(:, 1))
subplot(4,1,2)
plot(biglove{3}(:, 2))
hold on
plot(glove3(:, 2))
subplot(4,1,3)
plot(biglove{3}(:, 3))
hold on
plot(glove3(:, 3))
subplot(4,1,4)
plot(biglove{3}(:, 5))
hold on
plot(glove3(:, 5))

%% Downsample new labels to match features
% Decimate filters then takes every rth value from the filtered signal
% Do not use decimate for binary biglove matrices (will not get 0 or 1)
% biglove1_down = [];
% biglove2_down = [];
% biglove3_down = [];
% 
% for i = 1:5
%     biglove1_down(:, end+1) = decimate(biglove{1}(:, i), 50);
%     biglove2_down(:, end+1) = decimate(biglove{2}(:, i), 50);
%     biglove3_down(:, end+1) = decimate(biglove{3}(:, i), 50);
% end 
% 

biglove1_down = biglove{1}(1:50:end, :);
biglove2_down = biglove{2}(1:50:end, :);
biglove3_down = biglove{3}(1:50:end, :);

biglove1_down = biglove1_down(1:end-1, :);
biglove2_down = biglove2_down(1:end-1, :);
biglove3_down = biglove3_down(1:end-1, :); 

% Label as: 1 = no movement, 2 = movement
biglove1_down(biglove1_down == 1) = 2;
biglove1_down(biglove1_down == 0) = 1;
biglove2_down(biglove2_down == 1) = 2;
biglove2_down(biglove2_down == 0) = 1;
biglove3_down(biglove3_down == 1) = 2;
biglove3_down(biglove3_down == 0) = 1;

binary_glove_down = {biglove1_down; biglove2_down; biglove3_down};

% similar for the original glove data
for s = 1:3
    biglove{s}(biglove{s}(:,:) == 1) = 2;
    biglove{s}(biglove{s}(:,:) == 0) = 1;
end

%% Perform PCA to reduce # features or channels used
metric = 1; % 1 = features matrix, 2 = ecog data (channels)
scores = cell(3,1);
switch metric
    case 1
        [coeff1,scores{1},latent1,tsquared1,explained1,mu1] = pca(feat1);
        [coeff2,scores{2},latent2,tsquared2,explained2,mu2] = pca(feat2);
        [coeff3,scores{3},latent3,tsquared3,explained3,mu3] = pca(feat3);
    case 2
        [coeff1,scores{1},latent1,tsquared1,explained1,mu1] = pca(ecog1);
        [coeff2,scores{2},latent2,tsquared2,explained2,mu2] = pca(ecog2);
        [coeff3,scores{3},latent3,tsquared3,explained3,mu3] = pca(ecog3);
end
disp('Finished PCA prior to log reg')

%% Visualize the percent variance explained
figure
subplot(3,1,1)
plot(1:length(explained1), cumsum(explained1))
xlim([1 30])
ylim([0 100])
subplot(3,1,2)
plot(1:length(explained2), cumsum(explained2))
xlim([1 30])
ylim([0 100])
subplot(3,1,3)
plot(1:length(explained3), cumsum(explained3))
xlim([1 30])
ylim([0 100])

%% Perform logistic regression
log_weights = cell(3, 5);
probabilities = cell(3, 5);

switch metric
    case 1
        feat_used = [1 2 30]; % from variance explained
        for sub = 1:3
            for finger = 1:5
                log_weights{sub, finger} = ...
                    mnrfit(scores{sub}(:,1:feat_used(sub)), binary_glove_down{sub}(:,finger));
                probabilities{sub, finger} = ...
                    mnrval(log_weights{sub,finger}, scores{sub}(:,1:feat_used(sub)));
            end
        end
    case 2
        feat_used = [30 2 40]; % from variance explained
        for sub = 1:3
            for finger = 1:5
                log_weights{sub, finger} = ...
                    mnrfit(scores{sub}(:,1:feat_used(sub)), biglove{sub}(:,finger));
                probabilities{sub, finger} = ...
                    mnrval(log_weights{sub,finger}, scores{sub}(:,1:feat_used(sub)));
            end
        end
end
% log2 = mnrfit(feat2, biglove2_down);
% prob2 = mnrval(log2, feat2);
% log3 = mnrfit(feat3, biglove3_down);
% prob3 = mnrval(log3, feat3);
disp('Finished log reg')

%% Visualize the binary predicted training data
figure
subplot(3,1,1)
plot(glove1_down(:,1))
subplot(3,1,2)
plot(binary_glove_down{1}(:,1))
subplot(3,1,3)
plot(probabilities{1,1}(:,2))

%% Use a SVM binary classifier
svm_pred = cell(3, 5);
svm_prob = cell(3, 5);
feat_used = [1 2 30]; % from variance explained
for sub = 1:3
    for finger = 1:5
        Mdl = fitcsvm(scores{sub}(:, 1:feat_used(sub)), binary_glove_down{sub}(:,finger)); 
        [svm_pred{sub, finger}, svm_prob{sub, finger}] = ...
            predict(Mdl, scores{sub}(:, 1:feat_used(sub)));
    end
end
% log2 = mnrfit(feat2, biglove2_down);
% prob2 = mnrval(log2, feat2);
% log3 = mnrfit(feat3, biglove3_down);
% prob3 = mnrval(log3, feat3);
disp('Finished SVM')

%% Visualize the binary predicted training data
figure
subplot(3,1,1)
plot(glove1_down(:,1))
subplot(3,1,2)
plot(binary_glove_down{1} (:,1))
subplot(3,1,3)
plot(svm_prob{1,1}(:,2))

%% Test it on the OH checkpoint predictions
figure
subplot(3,1,1)
plot(predicted_dg{1}(:,1))
subplot(3,1,2)
plot(biglove1_down(:,1))
subplot(3,1,3)
plot(prob1(:,2))

%%
save('logweights.mat', 'log1'); %, 'log2', 'log3');
save('trainlogprob.mat', 'prob1'); %, 'prob2', 'prob3');

%% Combine logistic with linear regression to generate predictions
testprob1 = mnrval(log1, testfeat1);
testprob2 = mnrval(log2, testfeat2);
testprob3 = mnrval(log3, testfeat3);

% Multiply linear with logistic regression result; alpha = 1
logweighted1 = testpred1.*testprob1;
logweighted2 = testpred2.*testprob2;
logweighted3 = testpred3.*testprob3;

% Spline interpolate
testup1 = [];
testup2 = [];
testup3 = [];

for i = 1:5
    testup1(:, i) = spline(1:size(logweighted1, 1), logweighted1(:, i), 1:1/50:size(logweighted1, 1)); %off by 1 problem?? should be 1/50
    testup2(:, i) = spline(1:size(logweighted2, 1), logweighted2(:, i), 1:1/50:size(logweighted2, 1));
    testup3(:, i) = spline(1:size(logweighted3, 1), logweighted3(:, i), 1:1/50:size(logweighted3, 1));
end 

testup1 = [zeros(150, 5); testup1; zeros(49, 5)];
testup2 = [zeros(150, 5); testup2; zeros(49, 5)];
testup3 = [zeros(150, 5); testup3; zeros(49, 5)];

predicted_dg = cell(3, 1);
predicted_dg{1} = testup1(1:147500, 1:5);
predicted_dg{2} = testup2(1:147500, 1:5);
predicted_dg{3} = testup3(1:147500, 1:5);

save('logcheckpoint1.mat', 'predicted_dg');