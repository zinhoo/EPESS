%   Code for sampling a truncated multi-variate normal using EPESS
  
%   Steps:
  
% 0. Set hyperparameters
%
% 1. Simulate a mvg, specify the constraints -- randomly for now
%
% 2. Get the  EP-approximation -- John's code
%
% 3. Perform ESS given the EP approximation
%
% 4. Plot distributions (if 2 dimensional)
%
% 5. Calculate the Effective Sample Size
%
% 6. HMC Comparison -- Ari's Code
%
% 7. HMC vs EPESS



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 0. Hyperparameters
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Hyperparameters that are constant for all alphas, dimensions,...
number_samples = 1000; % Eventually use 10000
number_examples = 1; % 20
number_chains = 4; %4

% Hyperparameters of the experiment
inverse_wishart_weight = 0.5; % The covariance is a convex combination of a identity and a matrix sampled from an inverse wishart
axis_interval = 1;  % length of the box interval along each dimension for axis-alligned method
distance_box_placement = 0; % How far is the box placed form the origin
dimensions =[2]; % [2,10,50,100]


% % Decide which algorithm to run
% run_epess = true;
% run_hmc = false;

% Hyperparameters for plotting
plotting_on_off = true; % True if plotting, false otherwise
plot_axis_interval = 1.5*(axis_interval+distance_box_placement); % The radius of the plot. Made larger than the radius of the mixture means so that can show what happens for a gaussian that sits on the boundary
grid_size = 200; % Number of points to plot along each axis

% Boundaries
lB = [100; -1];    
uB = [101;1];

% Effective Sample Size
neff = zeros(length(dimensions), number_examples); % We will average over the examples
% neff_hmc = zeros(length(dimensions), number_examples);


% addpath([pwd,'/epmgp'])

for dimension_index = 1:length(dimensions)
    
    dimension = dimensions(dimension_index)
    inverse_wishart_df = dimension + 1.5; % Degrees of freedom of the inverse wishart
    
    for example_index = 1:number_examples
        example_index
        
        
        
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                % 1. Simulate a gaussian and specify the trauncation box (randomly)
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
                [mu, Sigma, chol_Sigma, C, lB, uB ] = simulateTmg( dimension, axis_interval, distance_box_placement, inverse_wishart_df, lB, uB);
                logLikelihood = @(x)( logPdfTmg( x, mu, chol_Sigma, C, lB, uB ));
             
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                % 2. Calculate the EP-approximation
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                
%               [logZ, mu_ep , Sigma_ep] = epmgp(mu,Sigma,C,lB,uB);
                [logZ, EP_mean , EP_covariance] = axisepmgp(mu,Sigma,lB,uB);
                EP_mean = EP_mean';
                EP_chol = chol(EP_covariance);
                                
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                % 3. Perform ESS given the EP approximation
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                disp('EPESS ESS') 
                tic 
                [ samples, number_fn_evaluations ] = epessSampler( number_samples , dimension, number_chains, logLikelihood, EP_mean, EP_chol );
                toc
%                 % Function for shifted pseduo-likelihood (the shift is so that the prior can be centered at zero)
%                 pseudoLogLikelihoodShifted = @(x)( logMixturePdfFn(x+EP_mean, number_mixtures, mixture_weights, mixture_means, mixture_chol ) ...
%                                                       - logGaussPdfChol(x', mu_ep, chol(Sigma_ep)));

                
%                 % Density at point x
%                 lB = lB-mu_ep;
%                 uB = uB-mu_ep;
%                 pseudoLogLikelihood = @(x)(logPdfTmg(x, mu-mu_ep, chol_Sigma, C, lB, uB) - logGaussPdfChol(x' , zeros(dimension,1), chol_ep));
%                 
%                 
%                 samples = zeros(number_samples , dimension, number_chains);
%                 for chain_index = 1:number_chains
% 
%                     % Initialize
%                     current_sample = ((lB+uB)/2)';
%                     samples(1,:,chain_index) = current_sample;
%                     cur_log_like = pseudoLogLikelihood(current_sample);
%                     number_fn_evaluations = 1;
%                     current_number_fn_evaluations = 0;
% 
%                     % Run MCMC
%                     for sample_index = 2 : number_samples
%                         [samples(sample_index,:,chain_index), cur_log_like , current_number_fn_evaluations] = elliptical_slice( samples(sample_index-1,:,chain_index) , chol_ep, pseudoLogLikelihood, cur_log_like);
%                         number_fn_evaluations = number_fn_evaluations + current_number_fn_evaluations;
%                     end
%                 end
                
%                 subplot(1,2,1);
%                 ezmesh(@(x,y)(pseudoLogLikelihood([x,y])), [-plot_axis_interval , plot_axis_interval] , grid_size)
%                 title('Pseduo-log-likelihood')
% %  
%                 subplot(1,2,2);

                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                % 4. Naive ESS -- Similar to HMC 
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


                disp('Naive ESS') 
                tic 
                naive_mean = zeros(dimension, 1);
                naive_sigma = eye(dimension);
                naive_chol = chol(naive_sigma);
                [ samples_naive, number_fn_evaluations_naive ] = epessSampler( number_samples , dimension, number_chains, logLikelihood, naive_mean', naive_chol, ((lB+uB)/2)'  ) ;
                toc
                
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                % 5. Excat HMC -- Ari's Matlab Implementation
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

                
                cov=true;  % we are specifying the covariance matrix
                 % Passing mu and Sigma -- the mean and covariance for tmg
                 % F and g denote the constraint matrix: Expressing all the
                 % constraints as F*X + g >= 0
                 
                 % initial point is tke to be in the middle of the box. For
                 % polyhedral constraints -- need to redo this
                 
                disp('Exact HMC') 
                tic 
                samples_exact = zeros(number_samples , dimension, number_chains);
                number_fn_evaluations = 1;
                initial_point = (lB+uB)/2;
                g = [-lB;uB];
                F = vertcat(eye(dimension), -eye(dimension));
                
                for chain_index = 1:number_chains
                     
                    samples_exact(:,:,chain_index) = HMC_exact(F, g, Sigma, mu, cov, number_samples, initial_point);
                
                end
                
                toc
                
                
                
                
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                % 6. Plotting 
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

                
                subplot(1,3,1);
                plot(samples(:,1), samples(:,2), 'x')
                axis([lB(1) , uB(1), lB(2), uB(2)])
                title('EP-ESS Samples')
                
%                 hold on 
%                 ezcontour(@(x,y)(mvnpdf([x;y], EP_mean' , EP_covariance)) , [lB(1)-.5 , uB(1)+.5, lB(2)-1, uB(2)+1] , grid_size)            
%                 axis([lB(1)-.5 , uB(1)+.5, lB(2)-1, uB(2)+1])
%                 title('EP-ESS Samples')
%                 hold off
%                 
                subplot(1,3,2);
                plot(samples_naive(:,1), samples_naive(:,2), 'x')
                axis([lB(1) , uB(1), lB(2), uB(2)])
                title('Naive-ESS Samples')
                
                subplot(1,3,3);
                plot(samples_exact(:,1), samples_exact(:,2), 'x')
                axis([lB(1) , uB(1), lB(2), uB(2)])
                title('Exact-HMC Samples')
                
                neff_epess = mpsrf(samples)
                neff_ess = mpsrf(samples_naive)
                neff_exact_hmc = mpsrf(samples_exact)
                
%                 
%                 subplot(1,3,3);
%                 ezmeshc(@(x,y)(logPdfTmg([x,y], mu, chol_Sigma, C, lB, uB )) , [lB(1)-0.5 , uB(1)+0.5, lB(2), uB(2)] , grid_size)
%                 title('Desnity plot of TMG')
%                 %ezmesh(@(x,y)(pseudoLogLikelihoodShifted([x,y])) , [-plot_axis_interval , plot_axis_interval] , grid_size)
%                 
%                 
                
                
                
       
    end
                
end
  
