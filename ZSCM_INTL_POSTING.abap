*&---------------------------------------------------------------------*
*& Function Module    ZSCM_INTL_POSTING
*&---------------------------------------------------------------------*
*& Transfer material to storage location from EWM (Post 411 movement in Cell)
*&---------------------------------------------------------------------*
*& Input : Pallet No, Supplying plant, Supplying SLOC, Receiving sloc
*& Output: Message
*&---------------------------------------------------------------------*
*& DDIC: Ensure structures ZSCM_BIN_INTL_POST_GET_DET_OUT (LGNUM, STOCK_ID,
*&       PARENT_ID) and ZSCM_BIN_INTL_POSTING_IN (WH_NUMBER, SCREEN_ID,
*&       STOCK_ID, PARENT_ID, IM_LOCATION) exist. Adjust FM parameter names
*&       for ZSCM_BIN_INTL_POST_GET_DET / ZSCM_BIN_INTL_POSTING if different.
*&---------------------------------------------------------------------*
FUNCTION zscm_intl_posting.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     REFERENCE(IM_PALLET_NO) TYPE /SCWM/DE_HUIDENT
*"     REFERENCE(IM_SUPPLYING_PLANT) TYPE WERKS_D
*"     REFERENCE(IM_SUPPLYING_SLOC) TYPE LGORT_D
*"     REFERENCE(IM_RECEIVING_SLOC) TYPE LGORT_D
*"  EXPORTING
*"     REFERENCE(EX_MESSAGE) TYPE BAPI_MSG
*"     REFERENCE(EX_SUCCESS) TYPE ABAP_BOOL
*"  EXCEPTIONS
*"      LGNUM_NOT_FOUND
*"      HU_NOT_FOUND
*"      GET_DET_FAILED
*"      POSTING_FAILED
*"----------------------------------------------------------------------

  DATA: lv_lgnum       TYPE /scwm/lgnum,
        lt_huhdr       TYPE STANDARD TABLE OF /scwm/s_huhdr_int,
        lt_huitm       TYPE STANDARD TABLE OF /scwm/s_huitm_int,
        lv_guid_hu     TYPE /scwm/guid_hu,
        lv_matnr       TYPE matnr,
        lt_output      TYPE STANDARD TABLE OF zscm_bin_intl_post_get_det_out,
        ls_output      TYPE zscm_bin_intl_post_get_det_out,
        ls_posting_in  TYPE zscm_bin_intl_posting_in,
        lt_tmapstloc   TYPE STANDARD TABLE OF /scwm/tmapstloc,
        lt_plant_sloc  TYPE STANDARD TABLE OF /scwm/tmapstloc,
        ls_plant_sloc  TYPE /scwm/tmapstloc,
        lr_huident     TYPE RANGE OF /scwm/de_huident,
        ls_huident     LIKE LINE OF lr_huident.

  DATA: lv_sys_user   TYPE uname.

  CLEAR: ex_message, ex_success.

*----------------------------------------------------------------------*
* Step 1: Get LGNUM from /scwm/tmapstloc using Plant and Supplying SLOC
* Rule 1: Use FOR ALL ENTRIES (prepare single entry for consistency)
*----------------------------------------------------------------------*
  ls_plant_sloc-plant    = im_supplying_plant.
  ls_plant_sloc-stge_loc = im_supplying_sloc.
  APPEND ls_plant_sloc TO lt_plant_sloc.

  IF lt_plant_sloc IS NOT INITIAL.
    SELECT mandt plant stge_loc lgnum
      FROM /scwm/tmapstloc
      INTO TABLE lt_tmapstloc
      FOR ALL ENTRIES IN lt_plant_sloc
      WHERE plant    = lt_plant_sloc-plant
        AND stge_loc = lt_plant_sloc-stge_loc.
  ENDIF.

  READ TABLE lt_tmapstloc INTO DATA(ls_tmapstloc) INDEX 1.
  IF sy-subrc <> 0 OR ls_tmapstloc-lgnum IS INITIAL.
    ex_success = abap_false.
    ex_message = 'LGNUM not found for given Plant and Supplying Storage Location'.
    RAISE lgnum_not_found.
  ENDIF.

  lv_lgnum = ls_tmapstloc-lgnum.

*----------------------------------------------------------------------*
* Step 2: Call /SCWM/HU_SELECT_GEN - get HU header and items
*----------------------------------------------------------------------*
  ls_huident-sign   = 'I'.
  ls_huident-option = 'EQ'.
  ls_huident-low    = im_pallet_no.
  APPEND ls_huident TO lr_huident.

  CALL FUNCTION '/SCWM/HU_SELECT_GEN'
    EXPORTING
      iv_lgnum   = lv_lgnum
      ir_huident = lr_huident
    IMPORTING
      et_huhdr   = lt_huhdr
      et_huitm   = lt_huitm
    EXCEPTIONS
      OTHERS     = 1.

  IF sy-subrc <> 0.
    ex_success = abap_false.
    ex_message = 'Error reading Handling Unit data'.
    RAISE hu_not_found.
  ENDIF.

  READ TABLE lt_huhdr INTO DATA(ls_huhdr) INDEX 1.
  IF sy-subrc <> 0.
    ex_success = abap_false.
    ex_message = 'Pallet/ HU not found'.
    RAISE hu_not_found.
  ENDIF.

  lv_guid_hu = ls_huhdr-guid_hu.

* Get MATNR from ET_HUITM by matching GUID_HU
  READ TABLE lt_huitm INTO DATA(ls_huitm)
    WITH KEY guid_hu = lv_guid_hu.
  IF sy-subrc <> 0.
    ex_success = abap_false.
    ex_message = 'Material not found for Pallet'.
    RAISE hu_not_found.
  ENDIF.

  lv_matnr = ls_huitm-matnr.

*----------------------------------------------------------------------*
* Step 3: Call ZSCM_BIN_INTL_POST_GET_DET
*----------------------------------------------------------------------*
  lv_sys_user = sy-uname.

  CALL FUNCTION 'ZSCM_BIN_INTL_POST_GET_DET'
    EXPORTING
      i_warehouse = lv_lgnum
      i_action    = 'A2'
      i_user      = lv_sys_user
    TABLES
      it_input    = VALUE #( ( matnr = lv_matnr ) )
      it_hu       = VALUE #( ( hu_id = im_pallet_no ) )
      et_output   = lt_output
    EXCEPTIONS
      OTHERS      = 1.

  IF sy-subrc <> 0.
    ex_success = abap_false.
    ex_message = 'Error in ZSCM_BIN_INTL_POST_GET_DET'.
    RAISE get_det_failed.
  ENDIF.

  READ TABLE lt_output INTO ls_output INDEX 1.
  IF sy-subrc <> 0.
    ex_success = abap_false.
    ex_message = 'No output from ZSCM_BIN_INTL_POST_GET_DET'.
    RAISE get_det_failed.
  ENDIF.

*----------------------------------------------------------------------*
* Step 4: Call ZSCM_BIN_INTL_POSTING
*----------------------------------------------------------------------*
  ls_posting_in-wh_number   = ls_output-lgnum.
  ls_posting_in-screen_id   = 'A2'.
  ls_posting_in-stock_id   = ls_output-stock_id.
  ls_posting_in-parent_id  = ls_output-parent_id.
  ls_posting_in-im_location = im_receiving_sloc.

  CALL FUNCTION 'ZSCM_BIN_INTL_POSTING'
    EXPORTING
      im_input = ls_posting_in
    EXCEPTIONS
      OTHERS   = 1.

  IF sy-subrc <> 0.
    ex_success = abap_false.
    ex_message = 'Posting failed in ZSCM_BIN_INTL_POSTING'.
    RAISE posting_failed.
  ENDIF.

  ex_success = abap_true.
  ex_message = 'Material transferred to receiving storage location successfully'.

ENDFUNCTION.
