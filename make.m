function make( mode )


if ~exist( 'mode', 'var' ) || isempty(mode); mode = 'all'; end

switch mode

  case 'clean'
    cd src/mex/+TetrisNAC
    delete *.mex*
    cd ../../..
    cd external
    delete *.mex*
    cd ..
    
  case {'all', 'debug'}

    cd src/mex/+TetrisNAC
    try
      if strcmp(mode, 'debug')
        fprintf('Compiling with debugging ON.\n');
        mex -g ...
          MexTetrisNAC.cpp Tetris.cpp NaturalActorCritic.cpp LSTDLambda.cpp LSPELambda.cpp FullTDLambda.cpp ...
          ../../../external/SeedFill.cpp
      else
        fprintf('Compiling with debugging OFF.\n');
        % mex -O -lcblas ...
        %   MexTetrisNAC.cpp Tetris.cpp NaturalActorCritic.cpp LSTDLambda.cpp LSPELambda.cpp FullTDLambda.cpp ...
        %   ../../../external/SeedFill.cpp
        mex -O ...
          COPTIMFLAGS="\$COPTIMFLAGS -O2" ...
          CXXOPTIMFLAGS="\$CXXOPTIMFLAGS -O2" ...
          LDOPTIMFLAGS="\$LDOPTIMFLAGS -O2" ...
          LDCXXOPTIMFLAGS="\$LDCXXOPTIMFLAGS -O2" ...
          MexTetrisNAC.cpp Tetris.cpp NaturalActorCritic.cpp LSTDLambda.cpp LSPELambda.cpp FullTDLambda.cpp ...
          ../../../external/SeedFill.cpp
      end
    catch err
    end
    cd ../../..

    cd external
    try
      mex -g getpid.c
    catch err
    end
    cd ..

    clear functions
    
end


end
