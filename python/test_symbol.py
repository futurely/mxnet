# pylint: skip-file
import mxnet as mx

data = mx.sym.Variable('data')
print data.debug_str()

fc1 = mx.sym.FullyConnected(data=data, name='fc1', no_bias=0)
fc2 = mx.sym.FullyConnected(data=fc1, name='fc2', no_bias=0)

print fc2.debug_str()

print fc2.list_arguments()

fc3 = mx.sym.FullyConnected(name='fc3')
fc4 = mx.sym.FullyConnected(data=fc3, name='fc4')

print fc4.debug_str()

print "-" * 10
composed_fc4 = fc4(fc3_data=fc2, name='composed')
print composed_fc4.debug_str()

