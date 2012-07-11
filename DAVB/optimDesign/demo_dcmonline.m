% Demo: on-line design optimization for DCM of fMRI data.


close all
clear variables
clc


%-----------------------------------------------------------
%-------------- DCM model specification --------------------

%--------- Basic settings ----------------------------------
n_t = 11;                    % number of time samples per block
nblocks = 10;               % number of blocks
TR = 3e0;                       % sampling period (in sec)
microDT = 5e-2;                 % micro-time resolution (in sec)
f_fname = @f_DCMwHRF;
g_fname = @g_HRF3;





%--------- model 1 -----------------------------------------
% invariant effective connectivity
A = [0 1
    1 0];
nreg = size(A,1);
% modulatory effects
B{1} = zeros(nreg,nreg);
B{2} = zeros(nreg,nreg);
B{2}(2,1) = 1;
% input-state coupling
C = [1 0
     0 0];
% gating (nonlinear) effects
D{1} = [0 0
    0 0];
D{2} = zeros(nreg,nreg);
D{3} = zeros(nreg,nreg);
% Build priors and options/dim structures for model inversion
[o4design{1},dim{1}] = getOptions4dcm(A,B,C,D,TR,microDT,n_t);


%--------- model 2 -----------------------------------------
% invariant effective connectivity
A = [0 1
    1 0];
nreg = size(A,1);
% modulatory effects
B{1} = zeros(nreg,nreg);
B{2} = zeros(nreg,nreg);
% input-state coupling
C = [1 0
     0 0];
% gating (nonlinear) effects
D{1} = [0 0
    0 0];
D{2} = zeros(nreg,nreg);
D{3} = zeros(nreg,nreg);
% Build priors and options/dim structures for model inversion
[o4design{2},dim{2}] = getOptions4dcm(A,B,C,D,TR,microDT,n_t);

nu = 2;
u1 = [zeros(1,floor(n_t/4)),ones(1,floor(n_t/2))];
u1(end:n_t) = 0;
u2 = zeros(1,n_t);
u0 = [u1;u2];

nm = length(dim);

truemodel = 1;
o4design{truemodel}.verbose = 0;

%---------- Simu parameters
t_A = exp([ -0.5
            -0.5
            ]);
t_Aself = -0;
t_B{1} = [];
t_B{2} = 1;
t_C = exp([ +0.1 ]);
t_D{1} = [];
t_D{2} = [];
theta = zeros(dim{truemodel}.n_theta,1);
phi = zeros(dim{truemodel}.n_phi,1);
theta(o4design{truemodel}.inF.indA) = t_A;
for i=1:nu
    theta(o4design{truemodel}.inF.indB{i}) = t_B{i};
end
theta(o4design{truemodel}.inF.indC) = t_C;
alpha = Inf;               % state noise precision
sigma = 1e1;                  % measurement noise precision


hf = figure;
ha = axes('parent',hf,'nextplot','replace');
e = zeros(2,1);
for tt=1:nblocks
    
    
    u{1} = u0;
    u{1}(2,end-n_t+1:end) = u1;
    
    u{2} = u0;
    
    fprintf(1,'\n')
    fprintf(1,['Optimizing design (block ',num2str(tt),')...'])
    fprintf(1,'\n')
    for i=1:length(u) %loops over experimental designs
        for j=1:length(dim)
            dim{j}.n_t = n_t;
        end
        [e(i,tt)] = designEfficiency(f_fname,g_fname,dim,o4design,u{i}(:,end-10:end),'models');
    end
    fprintf(1,['Optimizing design (block ',num2str(tt),')...  OK.'])
    fprintf(1,'\n')
    
    plot(ha,e','o')
    legend(ha,{'include 2nd input on this block','discard 2nd input opn this block'})
    xlabel(ha,'blocks')
    ylabel(ha,'design efficiency')
    
    [em,ind] = max(e(:,tt));
    uu = u{ind};
    
    fprintf(1,['Simulating data (block ',num2str(tt),')...  '])
    [y,x,x0,eta,ee] = simulateNLSS(length(uu),f_fname,g_fname,theta,phi,uu,alpha,sigma,o4design{truemodel});
    displaySimulations(y,x,eta,ee)
    fprintf(1,[' OK.'])        
    fprintf(1,'\n')
    
    fprintf(1,['VB (block ',num2str(tt),'):   inverting model       '])
    for j=1:length(o4design)
        fprintf(1,repmat('\b',1,6))
        fprintf(1,[num2str(j),'/',num2str(length(o4design)),'...'])
        dim{j} = rmfield(dim{j},'n_t');
        o4design{j}.DisplayWin = 0;
        o4design{j}.verbose = 0;
        [posterior,out] = VBA_NLStateSpaceModel(y(:,end-10:end),uu(:,end-10:end),f_fname,g_fname,dim{j},o4design{j});
        o4design{j}.priors = posterior;
        o4design{j}.priors.muX0 = posterior.muX(:,end);
        o4design{j}.priors.SigmaX0 = posterior.SigmaX.current{end};
    end
    fprintf(1,repmat('\b',1,24))
    fprintf(1,[' OK.'])        
    fprintf(1,'\n')
    
%     pause
    
    u0 = [uu,[u1;u2]];
    
    
end

figure,imagesc(uu)
title('chosen (online) design')
xlabel('time')
hold on
plot(get(gca,'xlim'),[1.5 1.5],'k')
set(gca,'ytick',[1,2],'yticklabel',{'u1','u2'})


