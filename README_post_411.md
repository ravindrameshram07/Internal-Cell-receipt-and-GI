# Post 411 Movement in Cell – Implementation Summary

## Reference
- **FS**: `FS_to_post_411_movement_in_Cell.md`
- **ABAP rules**: `../ABAP Rules/ABAP_Coding_Rules_and_API_Standard.md`

## Deliverables

### 1. ABAP – Function module `ZSCM_INTL_POSTING`
- **File**: `ZSCM_INTL_POSTING.abap`
- **Purpose**: Transfer material to storage location from EWM (post 411 movement).
- **Input**: Pallet No, Supplying plant, Supplying SLOC, Receiving sloc.
- **Output**: Message, Success.
- **Logic** (per FS):
  1. Read `/scwm/tmapstloc` (Plant, STGE_LOC) → get **LGNUM** (Rule 1: FOR ALL ENTRIES used).
  2. Call `/SCWM/HU_SELECT_GEN` (IV_LGNUM, IR_HUIDENT) → ET_HUHDR, ET_HUITM → **GUID_HU** → **MATNR** from ET_HUITM.
  3. Call `ZSCM_BIN_INTL_POST_GET_DET` (I_WAREHOUSE, I_ACTION=`A2`, I_USER, IT_INPUT-MATNR, IT_HU-HU_ID) → **ET_OUTPUT**.
  4. Call `ZSCM_BIN_INTL_POSTING` (WH_NUMBER, SCREEN_ID=`A2`, STOCK_ID, PARENT_ID, IM_LOCATION = Receiving sloc).
- **Rules applied**: Rule 1 (FOR ALL ENTRIES for table read). Rule 2 (Z_SAP_TO_REST_API) not used – no external API call in this FM.
- **DDIC**: Create/align structures `ZSCM_BIN_INTL_POST_GET_DET_OUT` and `ZSCM_BIN_INTL_POSTING_IN` and adjust FM parameter names if your system differs.

### 2. TypeScript – Types and service
- **Types**: `types/post-411-movement.ts` – `Post411MovementRequest`, `Post411MovementResponse`, `Post411MovementError`.
- **Service**: `service/post-411-movement.service.ts` – `Post411MovementService.postMovement()` calling the backend API that wraps `ZSCM_INTL_POSTING`.

If the backend exposes this via REST and uses **Z_SAP_TO_REST_API** (ABAP Rule 2), the API implementation should call that FM for the outbound HTTP call; the TS service remains the client to that REST endpoint.
