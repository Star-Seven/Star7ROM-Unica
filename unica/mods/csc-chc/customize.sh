SKIPUNZIP=1

# China (CHC) OMC replacement: drop the stock OXM multi-CSC OMC, then lay down the
# CHC single-CSC OMC extracted from the Galaxy S24 (SM-S9260).
LOG "- Dropping stock OMC (optics/prism) for the China (CHC) build"
DELETE_FROM_WORK_DIR "optics" "configs"
DELETE_FROM_WORK_DIR "prism" "etc"
DELETE_FROM_WORK_DIR "prism" "sipdb"
DELETE_FROM_WORK_DIR "prism" "HWRDB"

LOG "- Installing China (CHC) OMC"
ADD_TO_WORK_DIR "$MODPATH" "optics" "." 0 0 755 "u:object_r:vendor_configs_file:s0"
ADD_TO_WORK_DIR "$MODPATH" "prism" "." 0 0 755 "u:object_r:system_file:s0"
