function c = contenv (c,varargin)
% CONTENV get the signal envelope
  
  a = struct(...
      'envopt',[],...
      'method',[],...
      'rms_window_t',[],...
      'nosuffix', false);
  
  a = parseArgsLite(varargin,a);

  if ~isempty(a.envopt) && ~isempty(a.method),
    error('Can''t provide both ''method'' and ''envopt'' arguments')
  end
  
  if isempty(a.method)
    disp('no envelope method requested, using mkenvopt defaults')
    a.envopt = mkenvopt;
  else
    a.envopt = mkenvopt('method', a.method, ...
                        'rms_window_t', a.rms_window_t);
  end
  
  [nsamps nchans] = size(c.data); %#ok
  
  disp('calculating envelope...');

  switch(a.envopt.method)
   case 'hilbert'
    suffix = 'env_hilb';

    if any(isnan(c.data))
      error(['Cannot calculate Hilbert transform on data with NaNs; fix ' ...
             'data or use another method']); %#ok
    end

    for k = 1:nchans,

      % hilbert seems to be buggy with 'single' data; cast to double and back
      dtype = class(c.data);
      
      % get amplitude envelope (magnitude of the analytic signal)
      tmp = abs(hilbert(double(c.data(:,k))));

      % store result in the original data type
      c.data(:,k) = cast(tmp, dtype);

    end
    
   case 'peaks',
    % localmax works across columns
    % find all minima and maxima
    pks_idx = localmax(c.data);
    pks_idx = pks_idx | localmax(-c.data);
    
    for k = 1:nchans,
      % save some memory, maybe
      cdata_type = class(c.data);
      c.data(:,k) = interp1q(cast(find(pks_idx(:,k)), cdata_type), abs(c.data(pks_idx(:,k),k)), cast((1:nsamps)',cdata_type));
    end
    
    suffix = 'env_pks';
    
   case 'rms', 
    if isempty(a.envopt.rms_window_t),
      error('''rms_window_t'' must be provided for ''rms'' method');
    end
    
    if a.envopt.rms_window_t < (1.5/c.samplerate)
      warning(['rms window will be 1 sample or less, returning original ' ...
               'signal']);
    else
      % do RMS:
      % 1) Square signal
      c.data = c.data.^2;
      % 2) calculate moving Mean of squared signal
      c = contfilt(c, 'filtopt', mkfiltopt('name', 'rms_averaging',...
                                           'filttype', 'rectwin',...
                                           'length_t', a.envopt.rms_window_t));
      % 3) return Root of mean squared signal
      c.data = sqrt(c.data);
    end
    suffix = ['_rms_' num2str(a.envopt.rms_window_t*1000) 'ms'];
    
   otherwise
    error('unsupported envelope ''method''');
  end

  % create new chanlabels
  
  if ~isempty(c.chanlabels) && ~a.nosuffix
    for k = 1:nchans,
      c.chanlabels{k} = [c.chanlabels{k} suffix];
    end
  end
  
  % update data range
  c = contdatarange(c);
  
  
