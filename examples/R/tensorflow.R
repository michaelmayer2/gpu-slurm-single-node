# https://tensorflow.rstudio.com/examples/image_classification_from_scratch

library(tensorflow)
library(keras)
library(tfdatasets)
set.seed(1234)

url <- "https://download.microsoft.com/download/3/E/1/3E1C3F21-ECDB-4869-8368-6DEBA77B919F/kagglecatsanddogs_5340.zip"
options(timeout = 60 * 5) # 5 minutes
download.file(url, destfile = "kagglecatsanddogs_5340.zip") # (786.7 MB)
## To see a list of everything in the zip file:
# zip::zip_list("kagglecatsanddogs_5340.zip") |> tibble::as_tibble()
zip::unzip("kagglecatsanddogs_5340.zip")

fs::dir_info("PetImages")

n_deleted <- 0L
for(filepath in list.files("PetImages", pattern = "\\.jpg$",
                           recursive = TRUE, full.names = TRUE)) {
  header <- readBin(filepath, what = "raw", n = 10)
  if(!identical(header[7:10], charToRaw("JFIF"))) {
    n_deleted <- n_deleted + 1L
    unlink(filepath)
  }
}

cat(sprintf("Deleted %d images\n", n_deleted))

image_size <- c(180, 180)
batch_size <- 32

train_ds <- image_dataset_from_directory(
  "PetImages",
  validation_split = 0.2,
  subset = "training",
  seed = 1337,
  image_size = image_size,
  batch_size = batch_size,
)
val_ds <- image_dataset_from_directory(
  "PetImages",
  validation_split = 0.2,
  subset = "validation",
  seed = 1337,
  image_size = image_size,
  batch_size = batch_size,
)

data_augmentation <-
  keras_model_sequential(input_shape = c(image_size, 3)) %>%
  layer_random_flip("horizontal") %>%
  layer_random_rotation(factor = 0.1)

train_ds <- train_ds %>%
  dataset_map(function(images, labels) {
    list(data_augmentation(images, training = TRUE),
         labels)
  })

# Prefetching samples in GPU memory helps maximize GPU utilization.
train_ds %<>% dataset_prefetch()
val_ds   %<>% dataset_prefetch()

make_model <- function(input_shape, num_classes) {
  
  inputs <- layer_input(shape = input_shape)
  
  x <- inputs %>%
    # data augmentation() ? %>%
    layer_rescaling(1.0 / 255)
  
  x <- x %>%
    layer_conv_2d(128, 3, strides = 2, padding = "same") %>%
    layer_batch_normalization() %>%
    layer_activation("relu")
  
  previous_block_activation <- x  # Set aside residual
  for (size in c(256, 512, 728)) {
    x <- x %>%
      layer_activation("relu") %>%
      layer_separable_conv_2d(size, 3, padding = "same") %>%
      layer_batch_normalization() %>%
      
      layer_activation("relu") %>%
      layer_separable_conv_2d(size, 3, padding = "same") %>%
      layer_batch_normalization() %>%
      
      layer_max_pooling_2d(3, strides = 2, padding = "same")
    
    # Project residual
    residual <- previous_block_activation %>%
      layer_conv_2d(filters = size, kernel_size = 1, strides = 2,
                    padding = "same")
    
    x <- tf$keras$layers$add(list(x, residual))  # Add back residual
    previous_block_activation <- x  # Set aside next residual
  }
  
  x <- x %>%
    layer_separable_conv_2d(1024, 3, padding = "same") %>%
    layer_batch_normalization() %>%
    layer_activation("relu") %>%
    layer_global_average_pooling_2d()
  
  if (num_classes == 2) {
    activation <- "sigmoid"
    units <- 1
  } else {
    activation <- "softmax"
    units <- num_classes
  }
  
  outputs <- x %>%
    layer_dropout(0.5) %>%
    layer_dense(units, activation = activation)
  
  return(keras_model(inputs, outputs))
}

model <- make_model(input_shape = c(image_size, 3), num_classes = 2)

epochs <- 25

callbacks <- list(callback_model_checkpoint("save_at_{epoch}.keras"))
model %>% compile(
  optimizer = optimizer_adam(1e-3),
  loss = "binary_crossentropy",
  metrics = list("accuracy"),
)
history <- model %>% fit(
  train_ds,
  epochs = epochs,
  callbacks = callbacks,
  validation_data = val_ds,
)
plot(history)
