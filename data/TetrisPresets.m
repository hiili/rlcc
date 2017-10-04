function [theta0, w0] = TetrisPresets( name )
%TETRISPRESETS Initial policies for the Tetris benchmark
%
%   [theta0, w0] = TetrisPresets( name )
%
% ...
%
% The value (1) chosen for the immediate reward feature parameter is ad hoc.


switch name
  case '0'
    w0 = zeros(22,1); theta0 = w0;
  case 'BeI96'
    w0(1:10)  = 0;    % preferences for column heights
    w0(11:19) = 0;    % preferences for height differences of adjacent columns
    w0(20)    = -10;  % preference for high maximum height
    w0(21)    = -1;   % preference for holes
    w0(22)    = 0;    % bias
    theta0 = 1 * w0;  % determinism; not from BeT, in which a greedy approach was used
    theta0(23) = 1;    % add immediate reward parameter to the policy
  case 'h0'   % a stable 'seed' for gradients. why?
    w0(1:10)  = 0;    % preferences for column heights
    w0(11:19) = 0;    % preferences for height differences of adjacent columns
    w0(20)    = 1;    % preference for high maximum height
    w0(21)    = -3;   % preference for holes
    w0(22)    = 0;    % bias
    theta0 = 1 * w0;  % determinism
    theta0(23) = 1;    % add immediate reward parameter to the policy
  case 'h20'
    w0(1:10)  = 0;    % preferences for column heights
    w0(11:19) = 0;    % preferences for height differences of adjacent columns
    w0(20)    = -3;   % preference for high maximum height
    w0(21)    = -3;   % preference for holes
    w0(22)    = 0;    % bias
    theta0 = 1 * w0;  % determinism
    theta0(23) = 1;    % add immediate reward parameter to the policy
  case 'h20b'
    w0(1:10)  = 0;    % preferences for column heights
    w0(11:19) = 0;    % preferences for height differences of adjacent columns
    w0(20)    = -3;   % preference for high maximum height
    w0(21)    = -3;   % preference for holes
    w0(22)    = 100;  % bias
    theta0 = 1 * w0;  % determinism
    theta0(23) = 1;    % add immediate reward parameter to the policy
  case 'h50'
    % From experiment 2011-10-18_hide_terminal_actions/immediate_reward_feature__terminal_reject.
    % Enables repeating the nips 2011 results while having a clean implementation of termination.
    w0(1:10)  = 0;    % preferences for column heights
    w0(11:19) = -1;   % preferences for height differences of adjacent columns
    w0(20)    = 0;    % preference for high maximum height
    w0(21)    = -3;  % preference for holes
    w0(22)    = 0;    % bias
    theta0 = 1 * w0;  % determinism
    theta0(23) = 1;    % add immediate reward parameter to the policy. the chosen value (1) is ad hoc.
  case 'h300'
    w0(1:10)  = 0;    % preferences for column heights
    w0(11:19) = -2;   % preferences for height differences of adjacent columns
    w0(20)    = 0;    % preference for high maximum height
    w0(21)    = -10;  % preference for holes
    w0(22)    = 0;    % bias
    theta0 = 1 * w0;  % determinism
    theta0(23) = 1;    % add immediate reward parameter to the policy
  case 'h500'   % rename to h1k
    w0(1:10)  = -0.2;  % preferences for column heights
    w0(11:19) = -2;    % preferences for height differences of adjacent columns
    w0(20)    = -0.2;  % preference for high maximum height
    w0(21)    = -9;    % preference for holes
    w0(22)    = 0;     % bias
    theta0 = 1 * w0;   % determinism
    theta0(23) = 1;    % add immediate reward parameter to the policy
  case 'rl60'
    % no total divergence with fragile greedys; is the equilibrium solution of some greedys
    % _very_ fast convergence even with 5eps/it
    theta0 = [...
      0.2923 -0.4684 -0.0689 -0.2698 -0.2786 -0.2376 -0.1493 -0.2317 -0.4885 0.3459 ...
      -0.9277 -0.4333 -0.6222 -0.4065 -0.6442 -0.4164 -0.6487 -0.3404 -0.9073 ...
      0.8937 -3.4472 99.9077 ];
    w0 = theta0;   % ad hoc
    theta0(23) = 1;    % add immediate reward parameter to the policy
  case 'rl700'
    theta0 = [  -29.0525  -42.1910  -39.0768  -36.1179  -37.1043  -39.3445  -39.0529  -41.6495  -45.4712  -25.2952 ...
                -13.5015  -13.0435  -11.8708   -9.4471   -9.3966   -6.7113   -9.4271   -8.4788  -14.2067  ...
                -9.0041  -10.1011    0.0000 ];
    w0 = theta0;   % ad hoc
    theta0(23) = 1;    % add immediate reward parameter to the policy
  case 'rl5k'
    theta0 = [...
      3.7281 -2.9649 -0.2856 -0.9988 -0.8226 -0.8519 -0.9341 -0.2271 -3.0372 3.7068 ...
      -6.6119 -5.2318 -5.2004 -5.1899 -5.1374 -5.1637 -5.0805 -5.1928 -6.5163 ...
      -3.7904  -30.7750 -2.1088 ];
    w0 = theta0;   % ad hoc
    theta0(23) = 1;    % add immediate reward parameter to the policy
  case 'rl11k'
    theta0 = [...
      7.5784 -4.1452 2.2106 1.3475 0.6839 1.9997 0.1198 1.9487 -3.0799 7.7530 ...
      -7.9163 -8.2509 -5.8590 -7.2113 -6.7022 -6.8793 -7.1981 -5.8632 -8.2732 ...
      -11.7132 -41.7485 827.5050 ];
    w0 = theta0;   % ad hoc
    theta0(23) = 1;    % add immediate reward parameter to the policy
  case 'rl20k'
    theta0 = [ ...
          2.6618763026618, ...
         -3.9693346469853, ...
         -1.34476303740249, ...
         -1.85826182585595, ...
         -1.45318180388551, ...
         -1.38278730023602, ...
         -1.68030418235535, ...
         -1.22397859019636, ...
         -3.67957277987272, ...
          2.68687229525909, ...
         -5.83653542117396, ...
         -4.49192890298588, ...
         -4.73153136454566, ...
         -4.12631140039299, ...
         -4.21359363860415, ...
         -4.32384962580052, ...
         -4.50432335486979, ...
         -4.43420066389518, ...
         -5.70408724262032, ...
         -2.92571164056322, ...
         -28.6058355583426, ...
          999.456525120004 ];
    %theta0 = theta0 + 0.01 * randn(1,22);
    w0 = theta0;   % ad hoc
    theta0(23) = 1;    % add immediate reward parameter to the policy
  case 'rl40k'
    theta0 = [   9.3031   -9.0241   -1.3836    1.0806   -1.4388   -3.6479   -2.9481   -1.8309   -5.5468    8.0583  ...
               -15.0491  -12.4838  -11.9977  -10.8818  -12.0632  -10.7529  -11.7907   -9.6457  -14.3969  ...
                -8.6676  -70.0725  100.0000 ];
    w0 = theta0;   % ad hoc
    theta0(23) = 1;    % add immediate reward parameter to the policy
  case 'rl90k'
    theta0 = [   5.5412   -4.2570   -0.5213   -2.2085   -1.3219    0.3571   -3.0387    1.2092   -5.0223    5.8073 ...
               -10.1073   -4.8284   -8.1087   -9.0693   -7.4304   -6.1902   -8.5249   -5.1742  -11.0737 ...
               -2.0455  -36.7467     0 ];
    w0 = theta0;   % ad hoc
    theta0(23) = 1;    % add immediate reward parameter to the policy
  case 'rl150k'
    theta0 = [   7.5244   -5.9632   -0.6154   -3.1460   -1.9783    0.1639   -3.6595    1.1755   -7.0482    8.1939 ...
               -14.4604   -7.5516  -12.1045  -12.1682  -10.9341   -9.4672  -12.4014   -7.9894  -15.8063 ...
                -2.6200  -56.6585    0 ];
    w0 = theta0;   % ad hoc
    theta0(23) = 1;    % add immediate reward parameter to the policy
  otherwise
    assert( false, 'Unknown theta0 preset name ''%s''!', name );
end


% enforce into column vectors
theta0 = theta0(:);
w0 = w0(:);


end
