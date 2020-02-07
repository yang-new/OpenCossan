function optimum = apply(obj, varargin)
    %   APPLY   This method applies the algorithm
    %           GeneticAlgorithms for optimization
    %
    %   GeneticAlgorithms is intended for solving an optimization
    %   problem using evaluations of the objective function and constraints,
    %   i.e. gradients are not required.
    %
    %   GeneticAlgorithms is intended for solving the following
    %   class of problems
    %
    %                       min     f_obj(x)
    %                       subject to
    %                               ceq(x)      =  0
    %                               cineq(x)    <= 0
    %                               lb <= x <= ub
    %
    % See also: https://cossan.co.uk/wiki/index.php/apply@GeneticAlgorithms
    %
    % Author: Edoardo Patelli
    % Institute for Risk and Uncertainty, University of Liverpool, UK
    % email address: openengine@cossan.co.uk
    % Website: http://www.cossan.co.uk
    
    %{
    This file is part of OpenCossan <https://cossan.co.uk>.
    Copyright (C) 2006-2018 COSSAN WORKING GROUP

    OpenCossan is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License or,
    (at your option) any later version.

    OpenCossan is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with OpenCossan. If not, see <http://www.gnu.org/licenses/>.
    %}
    
    import opencossan.optimization.OptimizationRecorder;
    import opencossan.common.utilities.*;
    
    [required, varargin] = parseRequiredNameValuePairs(...
        "optimizationproblem", varargin{:});
    
    optProb = required.optimizationproblem;
    
    optional = parseOptionalNameValuePairs(...
        ["initialsolution", "plotevolution"], {optProb.InitialSolution, false}, ...
        varargin{:});
    
    x0 = optional.initialsolution;
    plotEvolution = optional.plotevolution;
    %  Check whether or not required arguments have been passed
    
    % Check inputs and initialize variables
    obj = initializeOptimizer(obj);
    
    memoizedModel = opencossan.optimization.memoizeModel(optProb);
    
    % Create handle of the objective function
    hobjfun=@(x)evaluate(optProb.ObjectiveFunctions,'optimizationproblem', optProb, ...
        'referencepoints',x , ...
        'model', memoizedModel, ...
        'scaling', obj.ObjectiveFunctionScalingFactor);
    
    % Create handle of the objective function
    hconstrains=@(x)evaluate(optProb.Constraints,'optimizationproblem', optProb, ...
        'referencepoints', x, ...
        'model', memoizedModel, ...
        'scaling', obj.ConstraintScalingFactor);
    
    assert(size(x0, 1) <= obj.NPopulationSize, ...
        'OpenCossan:GeneticAlgorithms:apply', ...
        ['Initial population must be less the NpopulationSize (' num2str(obj.NPopulationSize) ')'])
    
    assert(size(x0, 2) == length(optProb.DesignVariableNames), ...
        'OpenCossan:GeneticAlgorithms:apply', ...
        'Initial solution must contain a number of columns equal to the number of design variables');
    
    %% Prepare options structure for GeneticAlgorithms
    options                    = gaoptimset;                %Default optimization options
    options.InitialPopulation  = x0;      % Define the initial population
    options.PopulationSize     = obj.NPopulationSize;      %scalar, number of individuals in population
    options.EliteCount         = obj.NEliteCount;          %scalar, indicates the number of elite individuals that are passed directly to the next generation
    options.CrossoverFraction  = obj.crossoverFraction;    %percentage of individuals of the next generation that are generated by means of crossover operations
    options.Generations        = obj.MaxIterations;         %scalar defining maximum number of generations to be created
    options.StallGenLimit      = obj.NStallGenLimit;       %scalar; the optimization algorithm stops if there has been no improvement in the objective function for 'NStallGenLimit' consecutive generations
    options.TolFun             = obj.ObjectiveFunctionTolerance;   %Termination criterion w.r.t. objective function; algorithm is stopped if the  cumulative change of the fitness function over 'NStallGenLimit' is less than 'ToleranceObjectiveFunction'
    options.TolCon             = obj.ConstraintTolerance;          %Defines tolerance w.r.t. constraints
    options.InitialPenalty     = obj.initialPenalty;               %Initial value of penalty parameter; used in constrained optimization
    options.PenaltyFactor      = obj.PenaltyFactor;                %parameter for updating the penalty factor; required in constrained optimization
    options.FitnessScalingFcn  = str2func(obj.SFitnessScalingFcn); %eval(['@' SFitnessScalingFcn]);   %scaling of fitness function
    options.SelectionFcn       = str2func(obj.SSelectionFcn);      %eval(['@' SSelectionFcn]);        %function for selecting parents for crossover and mutation
    options.CrossoverFcn       = str2func(obj.SCrossoverFcn);      %eval(['@' SCrossoverFcn]);        %function for generating crossover children
    options.MutationFcn       = str2func(obj.SMutationFcn);
    options.CreationFcn       = str2func(obj.SCreationFcn);
    options.Display            = 'iter';    %sets level of display
    options.Vectorized         = 'on';     %enables possibility of calculating fitness of population using a single function callXop.VlowerBounds,Xop.VupperBounds
    options.TimeLimit          = obj.Timeout; % termination criteria
    
    opencossan.optimization.OptimizationRecorder.clear();
    
    startTime = tic;
    if isempty(optProb.Constraints)
        if plotEvolution
            options = gaoptimset('PlotFcns',{@gaplotbestf});
        end
        
        if ~obj.LextremeOptima
            % Run constrained optimisation
            [optimalSolution,~,exitFlag, ~] =ga(hobjfun,...
                Xop.NumberOfDesignVariables,[],[],[],[],optProb.LowerBounds,optProb.UpperBounds,...
                [],options);
        else
            % Run unconstrained extreme-values optimization with bounded
            % design variables
            [optimalSolution,~,exitFlag,~] =ga_minmax(hobjfun,...
                optProb.NumberOfDesignVariables,[],[],[],[],...
                optProb.LowerBounds,optProb.UpperBounds,[],options);
        end
        
    else
        
        if plotEvolution
            options = gaoptimset('PlotFcns',{@gaplotbestf,@gaplotmaxconstr});
        end
        
        if ~obj.LextremeOptima
            % Run constrained optimisation
            [optimalSolution,~,exitFlag, ~] =ga(hobjfun,...
                optProb.NumberOfDesignVariables,[],[],[],[],optProb.LowerBounds,optProb.UpperBounds,...
                hconstrains,...
                options);
        else
            % Run unconstrained extreme-values optimization with bounded
            % design variables
            [optimalSolution,~,exitFlag,~] =ga_minmax(hobjfun,...
                optProb.NumberOfDesignVariables,[],[],[],[],...
                optProb.LowerBounds,optProb.UpperBounds,[],options);
        end
    end
    
    totalTime = toc(startTime);
    
    optimum = opencossan.optimization.Optimum(...
        'optimalsolution', optimalSolution, ...
        'exitflag', exitFlag, ...
        'totaltime', totalTime, ...
        'optimizationproblem', optProb, ...
        'optimizer', obj, ...
        'constraints', OptimizationRecorder.getInstance().Constraints, ...
        'objectivefunction', OptimizationRecorder.getInstance().ObjectiveFunction, ...
        'modelevaluations', OptimizationRecorder.getInstance().ModelEvaluations);
    
    if ~isdeployed; obj.saveOptimumToDatabase(optimum); end
end

