classdef model < handle
%MODEL MXNet model, supports load and forward

properties
% The symbol definition, in json format
  symbol
% parameter weights
  params
% whether or not print info
  verbose
end

properties (Access = private)
% mxnet predictor
  predictor
% the previous input size
  prev_input_size
% the previous device id, -1 means cpu
  prev_dev_id
end

methods
  function obj = model()
  %CONSTRUCTOR
  obj.predictor = libpointer('voidPtr', 0);
  obj.prev_input_size = zeros(1,4);
  obj.verbose = 1;
  obj.prev_dev_id = -1;
  end

  function delete(obj)
  %DESTRUCTOR
  obj.free_predictor();
  end

  function load(obj, model_prefix, num_epoch)
  %LOAD load model from files
  %
  % A mxnet model is stored into two files. The first one contains the symbol
  % definition in json format. While the second one stores all weights in binary
  % format. For example, if we save a model using the prefix 'model/vgg19' at
  % epoch 8, then we will get two files. 'model/vgg19-symbol.json' and
  % 'model/vgg19-0009.params'
  %
  % model_prefix : the string model prefix
  % num_epoch : the epoch to load
  %
  % Example:
  %   model = mxnet.model
  %   model.load('outptu/vgg19', 8)

  % read symbol
  obj.symbol = fileread([model_prefix, '-symbol.json']);

  % read params
  fid = fopen(sprintf('%s-%04d.params', model_prefix, num_epoch), 'rb');
  assert(fid ~= 0);
  obj.params = fread(fid, inf, '*ubit8');
  fclose(fid);
  end

  function json = parse_symbol(obj)
  json = parse_json(obj.symbol);
  end


  function outputs = forward(obj, imgs, varargin)
  %FORWARD perform forward
  %
  % OUT = MODEL.FORWARD(imgs) returns the forward (prediction) outputs of a list
  % of images, where imgs can be either a single image with the format
  %\
  %   width x height x channel
  %
  % which is return format of `imread` or a list of images with format
  %
  %   width x height x channel x num_images
  %
  % MODEL.FORWARD(imgs, 'gpu', [0, 1]) uses GPU 0 and 1 for prediction
  %
  % MODEL.FORWARD(imgs, {'conv4', 'conv5'}) extract outputs for two internal layers
  %
  % Examples
  %
  %   % load and resize an image
  %   img = imread('test.jpg')
  %   img = imresize(img, [224 224])
  %   % get the softmax output
  %   out = model.forward(img)
  %   % get the output of two internal layers
  %   out = model.forward(img, {'conv4', 'conv5'})
  %   % use gpu 0
  %   out = model.forward(img, 'gpu', 0)
  %   % use two gpus for a image list
  %   imgs(:,:,:,1) = img1
  %   imgs(:,:,:,2) = img2
  %   out = model.forward(imgs, 'gpu', [0,1])

  % check arguments
  assert(length(varargin) == 0, 'sorry, not implemented yet..');

  % convert from matlab order (col-major) into c order (row major):
  siz = size(imgs);
  if length(siz) == 2
    imgs = permute(imgs, [2, 1]);
    siz = [siz, 1, 1];
  elseif length(siz) == 3
    imgs = permute(imgs, [2, 1, 3]);
    siz = [siz, 1];
  elseif length(siz) == 4
    imgs = permute(imgs, [2, 1, 3, 4]);
  else
    error('imgs shape error')
  end

  if any(siz ~= obj.prev_input_size)
    obj.free_predictor()
  end
  obj.prev_input_size = siz;

  dev_type = 1;
  if obj.predictor.Value == 0
    if obj.verbose
      fprintf('create predictor with input size ');
      fprintf('%d ', siz);
      fprintf('\n');
    end
    callmxnet('MXPredCreate', obj.symbol, ...
              libpointer('voidPtr', obj.params), ...
              length(obj.params), ...
              dev_type, 0, ...
              1, {'data'}, ...
              uint32([0, 4]), ...
              uint32(siz(end:-1:1)), ...
              obj.predictor);
  end

  % feed input
  callmxnet('MXPredSetInput', obj.predictor, 'data', single(imgs(:)), uint32(numel(imgs)));
  % forward
  callmxnet('MXPredForward', obj.predictor);

  % get output size
  out_dim = libpointer('uint32Ptr', 0);
  out_shape = libpointer('uint32PtrPtr', ones(4,1));
  callmxnet('MXPredGetOutputShape', obj.predictor, 0, out_shape, out_dim);
  assert(out_dim.Value <= 4);
  out_siz = out_shape.Value(1:out_dim.Value);
  out_siz = double(out_siz(:)');

  % get output
  out = libpointer('singlePtr', single(ones(out_siz)));

  callmxnet('MXPredGetOutput', obj.predictor, 0, ...
            out, uint32(prod(out_siz)));

  % TODO convert from c order to matlab order...
  outputs = out.Value;
  end
end

methods (Access = private)
  function free_predictor(obj)
  % free the predictor
  if obj.predictor.Value ~= 0
    if obj.verbose
      fprintf('destroy predictor\n')
    end
    callmxnet('MXPredFree', obj.predictor);
  end
  end
end

end
