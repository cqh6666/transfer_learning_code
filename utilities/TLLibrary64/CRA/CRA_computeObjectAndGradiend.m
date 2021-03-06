function [object,grad] = CRA_computeObjectAndGradiend(theta, numM, numK, numS, numX, alpha, beta, gamma, lambda, traindata, testdata, trainlabel)

    % convert theta to the (W1, W2, b1, b2) matrix/vector format
    W1 = reshape(theta(1:numK*numM), numK, numM);
    W2 = reshape(theta(numK*numM+1:2*numK*numM), numM, numK);
    b1 = theta(2*numK*numM+1:2*numK*numM+numK);
    b2 = theta(2*numK*numM+numK+1:2*numK*numM+numK+numM);
    C = reshape(theta(2*numK*numM+numK+numM+1:end), numS, numK);
    
    data = [traindata testdata];
    % Cost and gradient
    W1grad = zeros(size(W1)); 
    W2grad = zeros(size(W2));
    b1grad = zeros(size(b1)); 
    b2grad = zeros(size(b2));
    Cgrad = zeros(size(C));
    
    datasize = size(data, 2);
    
    weightsbuffer = ones(1, datasize);
    hiddeninputs = W1 * data + b1 * weightsbuffer;   % numK * datasize
    hiddenvalues = sigmoid(hiddeninputs);   % numK * datasize

    finalinputs = W2 * hiddenvalues + b2 * weightsbuffer; % numM * datasize
    outputs = sigmoid(finalinputs); % numM * datasize
    errors = outputs - data; %numM * numpatches
    clear weightsbuffer hiddeninputs finalinputs
    % Calculate J1  求解第一项
    J1 = sum(sum((errors .* errors)));
    %fprintf('J1: %d\n',J1);
    
    % Calculate J2  %求解第二项
    J2 = 0;
    for i = 1 : numS
        hiddenvalues_Traini = hiddenvalues(:,numX(1,i)+1 : 1 : numX(1,i+1));
        label_Traini = trainlabel(:,numX(1,i)+1 : 1 : numX(1,i+1));
        J2 = J2 - sum(log(sigmoid(label_Traini.*(C(i,:)*hiddenvalues_Traini))))...
             + lambda * sum(C(i,:).*C(i,:));
        clear hiddenvalues_Traini label_Traini;
    end
    %fprintf('J2: %d\n',J2);

    % Calculate J3%求解第三项
    J3 = 0;
    inputdata_test = testdata(:,:);
    datasize1 = size(inputdata_test,2);
    hiddenvalues_test = sigmoid(W1 * inputdata_test + b1 * ones(1, datasize1));   % hiddensize * datasize1
    temp_f = zeros(1,size(hiddenvalues_test,2));
    for u = 1 : numS
        temp_f = temp_f + sigmoid(C(u,:)*hiddenvalues_test)/numS;
    end
    J3 = J3 + sum(temp_f.*temp_f);
    temp_f = 1 - temp_f;
    J3 = J3 + sum(temp_f.*temp_f);
    clear inputdata_test hiddenvalues_test temp_f;
    %fprintf('J3: %d\n',J3);   
    
    % Calculate J4
    J4 = sum(sum(W1 .* W1)) +sum( sum(W2 .* W2)) + sum(b1 .* b1) + sum(b2 .* b2);
    %fprintf('J4: %d\n',J4);
    
    % Calculate Object
    object = J1 + alpha * J2 - beta * J3 + gamma * J4;
    
    clear J1 J2 J3 J4;
    
    W2grad1 = zeros(numM,numK);
    b2grad1 = zeros(numM,1);
    for i = 1 : numS+1
        Cgrad1 = zeros(1,numK);
        Cgrad2 = zeros(1,numK);
        %计算W2 b2梯度
        datasize1 = numX(1,i+1)-numX(1,i);
        hiddenvalues_Traini = hiddenvalues(:,numX(1,i)+1 : 1 : numX(1,i+1));
        outputs_Traini = outputs(:,numX(1,i)+1 : 1 : numX(1,i+1));
        errors_Traini = errors(:,numX(1,i)+1 : 1 : numX(1,i+1));
        W2grad1 = W2grad1 + 2*errors_Traini.*outputs_Traini.*(1-outputs_Traini)*hiddenvalues_Traini';
        b2grad1 = b2grad1 + 2*errors_Traini.*outputs_Traini.*(1-outputs_Traini)*ones(datasize1, 1); 
        %计算C梯度
        if i ~= numS+1
             %求解Ci的第一项的导数
            label_Traini = trainlabel(:,numX(1,i)+1 : 1 : numX(1,i+1));
            Cgrad1 = Cgrad1 - (1-sigmoid(label_Traini.*(C(i,:)*hiddenvalues_Traini))).*label_Traini*hiddenvalues_Traini' + 2*lambda*C(i,:);
            %fprintf('Cgrad1: %d\n',Cgrad1(1,4)); 
            inputdata_test = testdata(:,:);
            datasize1 = size(inputdata_test,2);
            hiddenvalues_test = sigmoid(W1 * inputdata_test + b1 * ones(1, datasize1));   % hiddensize * datasize1            
            temp_f = zeros(1,size(hiddenvalues_test,2));
            for u = 1 : numS
                temp_f = temp_f + 2*sigmoid(C(u,:)*hiddenvalues_test)/numS;
            end
            temp_f = temp_f - 1;
            fr = sigmoid(C(i,:)*hiddenvalues_test);
             %求解Ci的第二项导数
            Cgrad2 = Cgrad2 + 2*temp_f.*fr.*(1-fr)*hiddenvalues_test'/numS;
            %fprintf('Cgrad2: %d\n',Cgrad2(1,4));
            clear label_Traini inputdata_test hiddenvalues_test
        else
            break;
        end
        Cgrad(i,:) = alpha * Cgrad1 -  beta * Cgrad2;
        clear outputs_Traini errors_Traini hiddenvalues_Traini Cgrad1 Cgrad2;
    end
    
    W2grad = W2grad + W2grad1 + 2*gamma*W2;
    b2grad = b2grad + b2grad1 + 2*gamma*b2;
    clear W2grad1 b2grad1;
  
    %计算W1梯度
    W1grad1 = zeros(numK,numM);
    W1grad2 = zeros(numK,numM);
    W1grad3 = zeros(numK,numM);
    b1grad1 = zeros(numK,1);
    b1grad2 = zeros(numK,1);
    b1grad3 = zeros(numK,1);
    for i = 1 : numS+1
        datasize1 = numX(1,i+1)-numX(1,i);
        inputs_Traini = data(:,numX(1,i)+1 : 1 : numX(1,i+1));
        hiddenvalues_Traini = hiddenvalues(:,numX(1,i)+1 : 1 : numX(1,i+1));
        outputs_Traini = outputs(:,numX(1,i)+1 : 1 : numX(1,i+1));
        errors_Traini = errors(:,numX(1,i)+1 : 1 : numX(1,i+1));
        %求解W1 b1的第一项的导数
        W1grad1 = W1grad1 + 2 * W2'*(errors_Traini.*outputs_Traini.*(1-outputs_Traini)).*hiddenvalues_Traini.*(1-hiddenvalues_Traini)*inputs_Traini';
        b1grad1 = b1grad1 + 2 * W2'*(errors_Traini.*outputs_Traini.*(1-outputs_Traini)).*hiddenvalues_Traini.*(1-hiddenvalues_Traini)*ones(datasize1,1);
        
        if i ~=numS+1
            %求解W1 b1的第二项的导数
            label_Traini = trainlabel(:,numX(1,i)+1 : 1 : numX(1,i+1));
            W1grad2 = W1grad2 + C(i,:)'*((1-sigmoid(label_Traini.*(C(i,:)*hiddenvalues_Traini))).*label_Traini).*hiddenvalues_Traini.*(1-hiddenvalues_Traini)*inputs_Traini';
            b1grad2 = b1grad2 + C(i,:)'*((1-sigmoid(label_Traini.*(C(i,:)*hiddenvalues_Traini))).*label_Traini).*hiddenvalues_Traini.*(1-hiddenvalues_Traini)*ones(datasize1,1);
            clear label_Traini;
        else
            inputdata_test = testdata(:,:);
            datasize1 = size(inputdata_test,2);
            hiddenvalues_test = sigmoid(W1 * inputdata_test + b1 * ones(1, datasize1));   % hiddensize * datasize1
            
            for u = 1 : numS
                for r = 1 : numS
                    %求解W1 b1的第三项的导数
                    fu = sigmoid(C(u,:)*hiddenvalues_test);
                    fr = sigmoid(C(r,:)*hiddenvalues_test);
                    W1grad3 = W1grad3 + 2 * C(r,:)'*((fu-1/2).*fr.*(1-fr)).*hiddenvalues_test.*(1-hiddenvalues_test)*inputdata_test'*2/(numS*numS);
                    b1grad3 = b1grad3 + 2 * C(r,:)'*((fu-1/2).*fr.*(1-fr)).*hiddenvalues_test.*(1-hiddenvalues_test)*ones(datasize1,1)*2/(numS*numS);
                end
            end
            clear inputdata_test hiddenvalues_test;
        end
        clear inputs_Traini hiddenvalues_Traini outputs_Traini errors_Traini;
    end
    
    W1grad = W1grad + W1grad1 - alpha * W1grad2 - beta * W1grad3 +  2 * gamma * W1;   
    b1grad = b1grad + b1grad1 - alpha * b1grad2 - beta * b1grad3 +  2 * gamma * b1; 
    clear W1grad1 W1grad2 W1grad3 b1grad1 b1grad2 b1grad3 W1 b1 C W2 b2;
            
    grad = [W1grad(:) ; W2grad(:) ; b1grad(:) ; b2grad(:) ; Cgrad(:)];
    clear W1grad W2grad b1grad b2grad Cgrad hiddenvalues errors outputs data;
end

function sigm = sigmoid(x)
  
    sigm = 1 ./ (1 + exp(-x));
end