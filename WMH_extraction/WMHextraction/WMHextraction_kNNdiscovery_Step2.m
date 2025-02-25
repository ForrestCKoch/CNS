

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% WMHextraction_kNNdiscovery_Step2: kNN calculation %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


function WMHextraction_kNNdiscovery_Step2 (k, ID, classifier, template, probThr, trainingFeatures1, trainingFeatures2, nsegs, varargin)

switch classifier
    case 'built-in'
        feature4training = strcat (template.CNS_path, '/WMH_extraction/4kNN_classifier/feature_forTraining.txt');
        decision4training = strcat (template.CNS_path, '/WMH_extraction/4kNN_classifier/decision_forTraining.txt');
    case 'customised'
        feature4training = [template.studyFolder '/customiseClassifier/textfiles/feature_forTraining.txt'];
        decision4training = [template.studyFolder '/customiseClassifier/textfiles/decision_forTraining.txt'];
end

if exist (decision4training, 'file') == 2
    if exist (feature4training, 'file') == 2
        
        %% generate features for prediction
        if nargin == 8
            generateFeatures_forPrediction (ID, [template.studyFolder '/subjects'], template,nsegs);
        elseif (nargin >= 9) && strcmp(varargin{1},'noGenF')
            % no need to generate features
        elseif (nargin >= 9) && ~strcmp(varargin{1},'noGenF')
            generateFeatures_forPrediction (ID, [template.studyFolder '/subjects'], template,nsegs);
        end


        %% build kNN model
        if (nargin == 8) || ((nargin == 9) && strcmp(varargin{1},'noGenF'))
            int_kNN_mdl = build_kNN_classifier (k,feature4training, decision4training, trainingFeatures1);
        elseif nargin > 9 && strcmp(varargin{1},'noGenF')
            int_kNN_mdl = build_kNN_classifier (k,feature4training, decision4training, trainingFeatures1, varargin{2:end});
        elseif nargin > 8 && ~strcmp(varargin{1},'noGenF')
            int_kNN_mdl = build_kNN_classifier (k,feature4training, decision4training, trainingFeatures1, varargin{:});
        end

        
        %% examine the quality of the kNN model
        rloss = resubLoss(int_kNN_mdl); % Examine the resubstitution loss, which, by default, is the fraction of misclassifications from the predictions of Mdl.
        CVMdl = crossval(int_kNN_mdl); % Construct a cross-validated classifier from the model.
        kloss = kfoldLoss(CVMdl); % Examine the cross-validation loss, which is the average loss of each cross-validation model when predicting on data that is not used for training.
        
        fprintf('UBO Detector: resubstitution loss of the kNN model is %1.4f\n',rloss);
        fprintf('UBO Detector: cross-validation loss of the kNN model is %1.4f\n',kloss);

        %% predict
        predictionTBL_path = [template.studyFolder '/subjects/' ID '/mri/extractedWMH/temp/' ID '_feature_4prediction.txt'];
        predictionTBL = importdata(predictionTBL_path, ' ');
%         [label, score, cost] = predict (kNN_mdl, predictionTBL);
        [label, score, cost] = predict (int_kNN_mdl, predictionTBL(:,trainingFeatures1));
        

        %% saved seg012 clusters with label ID
        seg_lablIDs = cell(nsegs,1);
        for i = 1:nsegs
            seg_lablIDs{i} = niftiread([template.studyFolder,'/subjects/', ...
                ID,'/mri/extractedWMH/temp/',ID,'_seg',char(string(i-1)),'.nii']);
            seg_max(i) = max(max(max(seg_lablIDs{i})));
        end
        
        
        seg012_max = seg_max(1); 
        seg012_combined4D = seg_lablIDs{1};
        for i = 2:nsegs
            seg012_max = cat (2, seg012_max, seg_max(i));
            seg012_combined4D = cat (4, seg012_combined4D, seg_lablIDs{i});
        end
        
        clear seg_lablIDs;
        
        
%         seg012_combined4D_label = seg012_combined4D; % duplicate for assigning different values
        seg012_combined4D_score = seg012_combined4D;
        
        clear seg012_combined4D;
        
        %% probability map
        fprintf (['UBO Detector: generating WMH score map (i.e. WMH probability map) for ' ID ' ...\n']);

        offset = 0;
        for i = 1:nsegs
            score_cell {i} = score ((1+offset):(offset+seg_max(i)),2);
            offset = offset + seg_max(i);
        end
        
        dims = size(seg012_combined4D_score);
        for p = 1:nsegs

            % create an array of Linked Lists
            n_lists = seg012_max(1,p);
            java_linked_lists = java.util.ArrayList;
            for i = 1:n_lists
                java_linked_lists.add(java.util.LinkedList);
            end
            linked_lists = toArray(java_linked_lists);

            for z = 1:dims(3)
            for y = 1:dims(2)
            for x = 1:dims(1)
                val = seg012_combined4D_score(x,y,z,p);
                if val > 0
                    linked_lists(val).add([x,y,z]);
                end
            end
            end
            end

            for m = 1:seg012_max(1,p)
                ll = linked_lists(m);
                for q = 1:ll.size()
                    coord = ll.poll();
                    x = coord(1);
                    y = coord(2);
                    z = coord(3);
                    seg012_combined4D_score(x,y,z,p) = score_cell{p}(m);
                    
                end
            end
        end     
        
        seg012_score_img = seg012_combined4D_score(:,:,:,1) + seg012_combined4D_score(:,:,:,2) + seg012_combined4D_score(:,:,:,3);
        niftiwrite(seg012_score_img, [template.studyFolder '/subjects/' ID '/mri/extractedWMH/' ID '_WMH_ProbMap.nii']);

        % copy geometry
        [a,o] = system(['$FSLDIR/bin/fslcpgeom ' template.studyFolder '/subjects/' ID '/mri/extractedWMH/temp/' ID '_seg0'  ...
               ' ' template.studyFolder '/subjects/' ID '/mri/extractedWMH/' ID '_WMH_ProbMap']);

        
        clear seg012_combined4D_score;
        
        %% thresholded probability map
        fprintf (['UBO Detector: generating WMH map with probability threshold applied (probability threshold = ' num2str(probThr) ') for ' ID ' ...\n']);
        thresholded_probMap = seg012_score_img;
        
        clear seg012_score_img;
        
        thresholded_probMap (thresholded_probMap <= probThr) = 0;
        thresholded_probMap (thresholded_probMap > probThr) = 1;
        probThr = sprintf ('%1.2f', probThr); % two decimals
        probThr_parts = strsplit (probThr, '.');
        niftiwrite (thresholded_probMap, [template.studyFolder '/subjects/' ID '/mri/extractedWMH/' ID '_WMH_Prob' probThr_parts{1} '_' probThr_parts{2} '.nii']);
        system(['fslcpgeom ' template.studyFolder '/subjects/' ID '/mri/extractedWMH/temp/' ID '_seg0' ...
               ' ' template.studyFolder '/subjects/' ID '/mri/extractedWMH/' ID '_WMH_Prob' probThr_parts{1} '_' probThr_parts{2}]);

        clear thresholded_probMap;
        
    else
        fprintf ('%s\n', 'ERROR: no feature_forTraining.txt');
    end
else
    fprintf ('%s\n', 'ERROR: no decision_forTraining.txt');
end


    
    
    
    
    
