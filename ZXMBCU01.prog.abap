*&---------------------------------------------------------------------*
*& Include          ZXMBCU01
*& Package          ZPPPI
*&---------------------------------------------------------------------*
*& Part of User Exit: EXIT_SAPMM07M_001
*& Function Group  : MBCF
*& Triggered by    : Goods movement processing (MIGO / MB01 etc.)
*&---------------------------------------------------------------------*
*& Change History
*&---------------------------------------------------------------------*
*& Date        | Developer  | TR          | Description
*& ------------|------------|-------------|----------------------------
*& 10-Mar-2026 |            |             | Post 411 Movement in Cell
*&             |            |             | FS: FS_to_post_411_movement
*&             |            |             |     _in_Cell
*&---------------------------------------------------------------------*

*----------------------------------------------------------------------*
* This include is inserted into EXIT_SAPMM07M_001 which provides:
*   MKPF : Goods movement header (MBLNR, BUDAT, BLDAT, etc.)
*   MSEG : Goods movement item  (BWART, WERKS, LGORT, UMLGO, EXIDV ...)
*----------------------------------------------------------------------*

* >>>>>>>>>>>>>>>>>>> EXISTING CODE - DO NOT MODIFY <<<<<<<<<<<<<<<<<< *
*
*  (Retain all existing logic already present in the system here)
*
* >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>><<<<<<<<<<<<<<<<<<<<<<<<< *


*&---------------------------------------------------------------------*
*& BEGIN: Post 411 Movement in Cell – EWM Internal Posting
*& FS   : FS_to_post_411_movement_in_Cell
*& Date : 10-Mar-2026
*&
*& ABAP Rules applied:
*&   Rule 1 – FOR ALL ENTRIES used inside ZSCM_INTL_POSTING for the
*&             /scwm/tmapstloc table read (no INNER JOIN).
*&   Rule 2 – No external REST/HTTP call made here;
*&             Z_SAP_TO_REST_API is not applicable in this exit.
*&---------------------------------------------------------------------*

  DATA: lv_411_message TYPE bapi_msg,
        lv_411_success TYPE abap_bool.

* Only process 411 (Transfer SLoc -> SLoc) movements with HU assigned
  CHECK im_mseg-bwart = '411'.
  CHECK im_mseg-werks IS NOT INITIAL.
  CHECK im_mseg-exidv IS NOT INITIAL.   " External HU / Pallet No

  CALL FUNCTION 'ZSCM_INTL_POSTING'
    EXPORTING
      im_pallet_no       = im_mseg-exidv    " Pallet / HU identification
      im_supplying_plant = im_mseg-werks    " Supplying plant
      im_supplying_sloc  = im_mseg-lgort    " Issuing storage location
      im_receiving_sloc  = im_mseg-umlgo    " Receiving storage location
    IMPORTING
      ex_message         = lv_411_message
      ex_success         = lv_411_success
    EXCEPTIONS
      lgnum_not_found    = 1
      hu_not_found       = 2
      get_det_failed     = 3
      posting_failed     = 4
      OTHERS             = 5.

  IF sy-subrc <> 0 OR lv_411_success = abap_false.
    MESSAGE lv_411_message TYPE 'E'.        " Blocks goods movement post
  ENDIF.

*&---------------------------------------------------------------------*
*& END: Post 411 Movement in Cell
*&---------------------------------------------------------------------*
