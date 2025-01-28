import tensorflow as tf

# limit memory usage to 4 GB by creating a logical GPU device
gpus = tf.config.list_physical_devices('GPU')
tf.config.set_logical_device_configuration(
   gpus[0],
   [tf.config.LogicalDeviceConfiguration(memory_limit=4000)])
logical_gpus = tf.config.list_logical_devices('GPU')

# load data
mnist = tf.keras.datasets.mnist
(x_train, y_train),(x_test, y_test) = mnist.load_data()
x_train, x_test = x_train / 255.0, x_test / 255.0

# model defimition 
model = tf.keras.models.Sequential([
  tf.keras.layers.Flatten(input_shape=(28, 28)),
  tf.keras.layers.Dense(128, activation='relu'),
  tf.keras.layers.Dropout(0.2),
  tf.keras.layers.Dense(10, activation='softmax')
])

# compile model 
model.compile(optimizer='adam',
  loss='sparse_categorical_crossentropy',
  metrics=['accuracy'])

# run the actual fit
model.fit(x_train, y_train, epochs=5)

# check against test data
model.evaluate(x_test, y_test)

