library(lubridate)

# --- MANUAL CONFIGURATION ---
root <- "/Users/biomatic/Desktop/Pool01"  # ← Set your folder path here
start_datetime <- ymd_hm("2025-03-27 18:12", tz="")  # ← Set the timestamp of the oldest file here

# --- DO NOT MODIFY BELOW UNLESS NEEDED ---
start_ts <- as.numeric(as.POSIXct(start_datetime, tz = "UTC"))
x <- sub("^Pool", "", basename(root))

cat("\U0001F680 Starting timestamp correction in:", root, "\n")
cat("\U0001F4C5 Corrected base datetime:", format(start_datetime), "(", start_ts, ")\n")

all_files <- list.files(root, pattern = "\\.mp4$", recursive = TRUE, full.names = TRUE)
files <- all_files[!grepl("_CAM\\d+/", all_files)]
files <- sort(files)

first_fake_ts <- NA

for (filepath in files) {
  parts <- strsplit(filepath, .Platform$file.sep)[[1]]
  if (length(parts) < 5) {
    cat("⏭️ Skipping (too short path):", filepath, "\n")
    next
  }
  
  idx <- length(parts)
  mm_raw <- parts[idx]
  hh      <- parts[idx - 1]
  date    <- parts[idx - 2]
  w       <- parts[idx - 3]
  
  mm_clean <- sub("-new\\.mp4$", "", mm_raw)
  mm_clean <- sub("\\.mp4$", "", mm_clean)
  is_new <- grepl("-new\\.mp4$", mm_raw)
  mm <- mm_clean
  
  if (!grepl("^\\d{8}$", date) || !grepl("^\\d{1,2}$", hh) || !grepl("^\\d{1,2}$", mm)) {
    cat("⏭️ Skipping unmatched:", filepath, "\n")
    next
  }
  
  fake_ts <- as.numeric(ymd_hm(paste0(date, sprintf(" %02d:%02d", as.integer(hh), as.integer(mm)))))
  if (is_new) {
    fake_ts <- fake_ts + 86400
    cat("🔁 File marked -new, adjusted to next day:\n  ", filepath, "\n")
  }
  
  if (is.na(first_fake_ts)) first_fake_ts <- fake_ts
  
  delta <- fake_ts - first_fake_ts
  actual_ts <- start_ts + delta
  actual_time <- as.POSIXct(actual_ts, origin = "1970-01-01", tz = "")
  
  new_date <- format(actual_time, "%Y%m%d")
  new_time <- format(actual_time, "%H%M")
  
  target_dir <- file.path(root, paste0(new_date, "_CAM", w))
  if (!dir.exists(target_dir)) dir.create(target_dir, recursive = TRUE)
  
  new_filename <- paste0(x, "_", new_date, "_", new_time, ".mp4")
  new_file <- file.path(target_dir, new_filename)
  
  success <- file.rename(filepath, new_file)
  if (!success) {
    cat("❌ Failed to move:", filepath, "\n")
    next
  }
  
  Sys.setFileTime(new_file, actual_time)
  cat("✅", filepath, "→", new_file, "@", format(actual_time, "%Y-%m-%dT%H:%M:%S"), "\n")
}

junk_files <- list.files(root, pattern = "\\.DS_Store$|\\.start_time$", recursive = TRUE, full.names = TRUE)
for (f in junk_files) {
  tryCatch({
    file.remove(f)
    cat("🗑️ Removed junk file:", f, "\n")
  }, error = function(e) {
    cat("⚠️ Could not remove:", f, "\n")
  })
}

dirs <- list.dirs(root, recursive = TRUE, full.names = TRUE)
for (d in rev(dirs)) {
  if (d == root) next
  junk <- list.files(d, pattern = "^\\.DS_Store$|^\\.start_time$", full.names = TRUE, all.files = TRUE)
  for (f in junk) {
    tryCatch({
      file.remove(f)
      cat("🗑️ Removed junk file:", f, "\n")
    }, error = function(e) {
      cat("⚠️ Could not remove:", f, "\n")
    })
  }
  if (length(list.files(d, all.files = TRUE, no.. = TRUE)) == 0) {
    unlink(d, recursive = TRUE, force = TRUE)
    cat("🧹 Removed empty directory:", d, "\n")
  }
}

cat("\U0001F389 All files processed!\n")
