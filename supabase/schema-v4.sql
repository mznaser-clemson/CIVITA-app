-- ============================================================================
-- CIVITA v4 CANONICAL central database — schema + Row Level Security (RLS) + grants
-- Concrete Grand Challenge Experimental Database, 17-table canonical shape.
-- Architecture: Supabase, MERGE-FREE, NO LOGIN (anonymous), SUBMIT-ONLY, INSERT-ONLY.
--
-- This is the v4 canonical schema for a NEW, SEPARATE Supabase project. The old
-- 9-table supabase/schema.sql belongs to the v3 project and is kept as a BACKUP;
-- do NOT run this file against the v3 project. Point CENTRAL_DB_URL / anon key in
-- CIVITA-v4.html at the new project after running this in its SQL editor.
--
-- Run this in the Supabase SQL editor (Dashboard -> SQL Editor -> New query).
-- IDEMPOTENT: re-running reconciles columns (create-if-not-exists + add-column-if-not-
-- exists) and re-creates policies/grants without destroying data.
--
-- SECURITY MODEL (identical to v3 — trusted volunteer group, public research data, no
-- accounts, no PII worth attacking):
--   * NO AUTH. Requests use the anon key; the role is `anon`.
--   * INSERT-ONLY. anon is GRANTed INSERT plus a column-level SELECT on the PRIMARY KEY
--     ONLY; the only RLS policy is an INSERT policy. There is NO update/delete grant and
--     NO select policy (so REST reads still return zero rows — RLS blocks them).
--   * Re-submission is handled client-side with PLAIN inserts + duplicate tolerance: the
--     tool POSTs rows and treats a duplicate-key rejection (HTTP 409 / SQLSTATE 23505) as
--     "already present (skipped)", not a failure. We do NOT use ON CONFLICT DO NOTHING —
--     under RLS it fails 42501 unless a SELECT *policy* exists (which would expose reads).
--     The PK-only SELECT grant below is therefore VESTIGIAL — the plain-insert path needs
--     no SELECT at all. It is kept for structural parity with the v3 schema + so the drift
--     guard's grant assertions are uniform; it exposes nothing (there is still no SELECT
--     *policy* => API reads return zero rows regardless of this column grant).
--   * Globally-namespaced IDs (<emailprefix>-<datasettoken>-TYPE-NNNN) make collisions
--     impossible, so each table is the live UNION of every contribution — no merge step.
--   * keywords has NO single-column id: its PRIMARY KEY is composite (source_id, keyword),
--     so a re-submitted (source_id, keyword) pair is a 409 dup-skip like any other PK.
--
-- !!! HARD RULE: the service_role key BYPASSES every policy/grant below. It must NEVER
-- !!! appear in CIVITA-v4.html, the repo, or any client bundle. Only the ANON key goes in
-- !!! the HTML. service_role lives only in the Dashboard / coordinator-side local scripts.
--
-- Column names mirror TABLE_SCHEMAS in CIVITA-v4.html EXACTLY and are QUOTED so case is
-- preserved (e.g. "Notes", "initial_env_temperature_C") — PostgREST matches the tool's
-- JSON keys to columns case-sensitively, so an unquoted column would silently fold to
-- lowercase and drop data. All values are stored as text (the tool serializes every field
-- as a string). No cross-table FK CONSTRAINTS: the tool tolerates partial submissions
-- (dangling refs are advisory warnings, not errors); hard FKs would reject valid partials.
--
-- TO ADD A FIELD LATER: add it to TABLE_SCHEMAS in the HTML, add a matching
-- `add column if not exists "<name>" text` clause to the relevant ALTER below, and
-- re-run this file. tests/run_schema_sql_v4_tests.mjs fails if the two drift apart.
-- ============================================================================

-- ---------- literature_sources ----------
create table if not exists public."literature_sources" (
  "source_id" text primary key,
  "created_at" timestamptz not null default now()
);
alter table public."literature_sources"
  add column if not exists "source_type" text,
  add column if not exists "peer_reviewed" text,
  add column if not exists "title" text,
  add column if not exists "authors" text,
  add column if not exists "year" text,
  add column if not exists "journal_or_publisher" text,
  add column if not exists "volume" text,
  add column if not exists "issue" text,
  add column if not exists "pages" text,
  add column if not exists "doi" text,
  add column if not exists "url" text,
  add column if not exists "institution" text,
  add column if not exists "notes" text,
  add column if not exists "contributor_university" text,
  add column if not exists "contributor_name" text,
  add column if not exists "contributor_email" text;
alter table public."literature_sources" enable row level security;
revoke all on public."literature_sources" from anon, authenticated;
grant insert on public."literature_sources" to anon;
grant select ("source_id") on public."literature_sources" to anon;
drop policy if exists "literature_sources_insert_anon" on public."literature_sources";
create policy "literature_sources_insert_anon" on public."literature_sources" for insert to anon with check (true);

-- ---------- keywords ----------
create table if not exists public."keywords" (
  "source_id" text,
  "keyword" text,
  "created_at" timestamptz not null default now(),
  primary key ("source_id", "keyword")
);
alter table public."keywords" enable row level security;
revoke all on public."keywords" from anon, authenticated;
grant insert on public."keywords" to anon;
grant select ("source_id", "keyword") on public."keywords" to anon;
drop policy if exists "keywords_insert_anon" on public."keywords";
create policy "keywords_insert_anon" on public."keywords" for insert to anon with check (true);

-- ---------- material_batches ----------
create table if not exists public."material_batches" (
  "batch_id" text primary key,
  "created_at" timestamptz not null default now()
);
alter table public."material_batches"
  add column if not exists "source_id" text,
  add column if not exists "mixing_protocol_file_name" text,
  add column if not exists "batch_label" text,
  add column if not exists "material_class" text,
  add column if not exists "cement_type" text,
  add column if not exists "printable" text,
  add column if not exists "self_consolidating" text,
  add column if not exists "cement_content_kg_m3" text,
  add column if not exists "water_binder_ratio" text,
  add column if not exists "silica_fume_content_kg_m3" text,
  add column if not exists "fly_ash_content_kg_m3" text,
  add column if not exists "fly_ash_class" text,
  add column if not exists "slag_content_kg_m3" text,
  add column if not exists "fine_aggregate_content_kg_m3" text,
  add column if not exists "fine_aggregate_dry_density_kg_m3" text,
  add column if not exists "coarse_aggregate_content_kg_m3" text,
  add column if not exists "coarse_aggregate_dry_density_kg_m3" text,
  add column if not exists "max_aggregate_size_mm" text,
  add column if not exists "aggregate_type" text,
  add column if not exists "superplasticizer_type" text,
  add column if not exists "superplasticizer_content_kg_m3" text,
  add column if not exists "water_reducer_type" text,
  add column if not exists "water_reducer_content_ml_m3" text,
  add column if not exists "air_entrainment_type" text,
  add column if not exists "air_entrainment_content_ml_m3" text,
  add column if not exists "rheology_modifier_type" text,
  add column if not exists "rheology_modifier_content_kg_m3" text,
  add column if not exists "hydration_accelerator_type" text,
  add column if not exists "hydration_accelerator_content_ml_m3" text,
  add column if not exists "fiber_type" text,
  add column if not exists "fiber_product_name" text,
  add column if not exists "fiber_volume_fraction" text,
  add column if not exists "fiber_length_mm" text,
  add column if not exists "fiber_diameter_mm" text,
  add column if not exists "air_content_percent_volume_concrete" text,
  add column if not exists "date_of_pouring_yyyy-mm-dd" text,
  add column if not exists "notes" text;
alter table public."material_batches" enable row level security;
revoke all on public."material_batches" from anon, authenticated;
grant insert on public."material_batches" to anon;
grant select ("batch_id") on public."material_batches" to anon;
drop policy if exists "material_batches_insert_anon" on public."material_batches";
create policy "material_batches_insert_anon" on public."material_batches" for insert to anon with check (true);

-- ---------- reinforcement_materials ----------
create table if not exists public."reinforcement_materials" (
  "reinforcement_material_id" text primary key,
  "created_at" timestamptz not null default now()
);
alter table public."reinforcement_materials"
  add column if not exists "source_id" text,
  add column if not exists "reinforcement_material_type" text,
  add column if not exists "stress_strain_curve_file" text,
  add column if not exists "elastic_modulus_mpa" text,
  add column if not exists "yield_strength_mpa" text,
  add column if not exists "rupture_strength_mpa" text,
  add column if not exists "rupture_strain" text,
  add column if not exists "notes" text;
alter table public."reinforcement_materials" enable row level security;
revoke all on public."reinforcement_materials" from anon, authenticated;
grant insert on public."reinforcement_materials" to anon;
grant select ("reinforcement_material_id") on public."reinforcement_materials" to anon;
drop policy if exists "reinforcement_materials_insert_anon" on public."reinforcement_materials";
create policy "reinforcement_materials_insert_anon" on public."reinforcement_materials" for insert to anon with check (true);

-- ---------- geometries ----------
create table if not exists public."geometries" (
  "geometry_id" text primary key,
  "created_at" timestamptz not null default now()
);
alter table public."geometries"
  add column if not exists "source_id" text,
  add column if not exists "specimen_geometry_type" text,
  add column if not exists "specimen_geometry_file_name" text,
  add column if not exists "Notes" text;
alter table public."geometries" enable row level security;
revoke all on public."geometries" from anon, authenticated;
grant insert on public."geometries" to anon;
grant select ("geometry_id") on public."geometries" to anon;
drop policy if exists "geometries_insert_anon" on public."geometries";
create policy "geometries_insert_anon" on public."geometries" for insert to anon with check (true);

-- ---------- printing_variables ----------
create table if not exists public."printing_variables" (
  "printing_id" text primary key,
  "created_at" timestamptz not null default now()
);
alter table public."printing_variables"
  add column if not exists "source_id" text,
  add column if not exists "geometry_id" text,
  add column if not exists "printing_speed_mm_sec" text,
  add column if not exists "volumetric_flow_rate_m3_h" text,
  add column if not exists "nozzle_orientation_angle_deg" text,
  add column if not exists "nozzle_shape" text,
  add column if not exists "nozzle_size_mm" text,
  add column if not exists "extrusion_pressure_pa" text,
  add column if not exists "hose_length_m" text,
  add column if not exists "hose_diameter_mm" text,
  add column if not exists "pump_type" text,
  add column if not exists "pump_model" text,
  add column if not exists "arm_type" text,
  add column if not exists "number_of_dofs" text,
  add column if not exists "arm_model" text,
  add column if not exists "deliver_method" text;
alter table public."printing_variables" enable row level security;
revoke all on public."printing_variables" from anon, authenticated;
grant insert on public."printing_variables" to anon;
grant select ("printing_id") on public."printing_variables" to anon;
drop policy if exists "printing_variables_insert_anon" on public."printing_variables";
create policy "printing_variables_insert_anon" on public."printing_variables" for insert to anon with check (true);

-- ---------- reinforcement_layouts ----------
create table if not exists public."reinforcement_layouts" (
  "reinforcement_layout_id" text primary key,
  "created_at" timestamptz not null default now()
);
alter table public."reinforcement_layouts"
  add column if not exists "source_id" text,
  add column if not exists "geometry_id" text,
  add column if not exists "longitudinal_reinforcement" text,
  add column if not exists "transverse_reinforcement" text,
  add column if not exists "external_reinforcement" text,
  add column if not exists "reinforcement_file_name" text,
  add column if not exists "Notes" text;
alter table public."reinforcement_layouts" enable row level security;
revoke all on public."reinforcement_layouts" from anon, authenticated;
grant insert on public."reinforcement_layouts" to anon;
grant select ("reinforcement_layout_id") on public."reinforcement_layouts" to anon;
drop policy if exists "reinforcement_layouts_insert_anon" on public."reinforcement_layouts";
create policy "reinforcement_layouts_insert_anon" on public."reinforcement_layouts" for insert to anon with check (true);

-- ---------- reinforcement_components ----------
create table if not exists public."reinforcement_components" (
  "reinforcement_component_id" text primary key,
  "created_at" timestamptz not null default now()
);
alter table public."reinforcement_components"
  add column if not exists "source_id" text,
  add column if not exists "reinforcement_material_id" text,
  add column if not exists "reinforcement_layout_id" text,
  add column if not exists "notes" text,
  add column if not exists "reinforcement_type" text,
  add column if not exists "reinforcement_orientation" text,
  add column if not exists "number_of_reinf_elements" text,
  add column if not exists "bar_designation" text,
  add column if not exists "bar_nominal_diameter_mm" text,
  add column if not exists "bar_nominal_area_mm2" text,
  add column if not exists "layer_depth_mm" text,
  add column if not exists "spacing_mm" text,
  add column if not exists "horizontal_cover_mm" text,
  add column if not exists "vertical_cover_mm" text,
  add column if not exists "begin_distance_mm" text,
  add column if not exists "end_distance_mm" text,
  add column if not exists "reinforcement_centroid_x_mm" text,
  add column if not exists "reinforcement_centroid_y_mm" text,
  add column if not exists "reinforcement_centroid_z_mm" text,
  add column if not exists "reinforcement_width_mm" text,
  add column if not exists "reinforcement_length_mm" text,
  add column if not exists "reinforcement_thickness_mm" text,
  add column if not exists "reinforcement_angle_deg" text,
  add column if not exists "adhesive_type" text,
  add column if not exists "adhesive_thickness_mm" text,
  add column if not exists "adhesive_modulus_mpa" text,
  add column if not exists "adhesive_strength_mpa" text,
  add column if not exists "adhesive_failure_strain" text,
  add column if not exists "anchorage_presence" text,
  add column if not exists "anchorage_type" text,
  add column if not exists "anchorage_size_mm" text,
  add column if not exists "anchorage_location_x_mm" text,
  add column if not exists "anchorage_location_y_mm" text,
  add column if not exists "anchorage_location_z_mm" text,
  add column if not exists "anchorage_modulus_mpa" text,
  add column if not exists "anchorage_strength_mpa" text,
  add column if not exists "anchorage_failure_strain" text,
  add column if not exists "UNDER DEVELOPMENT" text;
alter table public."reinforcement_components" enable row level security;
revoke all on public."reinforcement_components" from anon, authenticated;
grant insert on public."reinforcement_components" to anon;
grant select ("reinforcement_component_id") on public."reinforcement_components" to anon;
drop policy if exists "reinforcement_components_insert_anon" on public."reinforcement_components";
create policy "reinforcement_components_insert_anon" on public."reinforcement_components" for insert to anon with check (true);

-- ---------- specimens ----------
create table if not exists public."specimens" (
  "specimen_id" text primary key,
  "created_at" timestamptz not null default now()
);
alter table public."specimens"
  add column if not exists "source_id" text,
  add column if not exists "batch_id" text,
  add column if not exists "geometry_id" text,
  add column if not exists "reinforcement_layout_id" text,
  add column if not exists "printing_variables_id" text,
  add column if not exists "structural_form_type" text,
  add column if not exists "notes" text;
alter table public."specimens" enable row level security;
revoke all on public."specimens" from anon, authenticated;
grant insert on public."specimens" to anon;
grant select ("specimen_id") on public."specimens" to anon;
drop policy if exists "specimens_insert_anon" on public."specimens";
create policy "specimens_insert_anon" on public."specimens" for insert to anon with check (true);

-- ---------- tests ----------
create table if not exists public."tests" (
  "test_id" text primary key,
  "created_at" timestamptz not null default now()
);
alter table public."tests"
  add column if not exists "source_id" text,
  add column if not exists "specimen_id" text,
  add column if not exists "number_of_repeats" text,
  add column if not exists "test_setup_visualization_file_name" text,
  add column if not exists "test_protocol_file_name" text,
  add column if not exists "test_type" text,
  add column if not exists "test_parameters_file_name" text,
  add column if not exists "main_observed_mechanisms" text,
  add column if not exists "age_days" text,
  add column if not exists "curing_condition" text,
  add column if not exists "hygral_boundary_conditions" text,
  add column if not exists "thermal_boundary_conditions" text,
  add column if not exists "initial_env_temperature_C" text,
  add column if not exists "env_temperature_C_history_file_name" text,
  add column if not exists "initial_env_relative_humidity_percent" text,
  add column if not exists "env_relative_humidity_percent_history_file_name" text,
  add column if not exists "test_date_yyyy-mm-dd" text,
  add column if not exists "notes" text;
alter table public."tests" enable row level security;
revoke all on public."tests" from anon, authenticated;
grant insert on public."tests" to anon;
grant select ("test_id") on public."tests" to anon;
drop policy if exists "tests_insert_anon" on public."tests";
create policy "tests_insert_anon" on public."tests" for insert to anon with check (true);

-- ---------- devices_and_supports ----------
create table if not exists public."devices_and_supports" (
  "device_id" text primary key,
  "created_at" timestamptz not null default now()
);
alter table public."devices_and_supports"
  add column if not exists "source_id" text,
  add column if not exists "test_id" text,
  add column if not exists "device_type" text,
  add column if not exists "x_location_mm" text,
  add column if not exists "y_location_mm" text,
  add column if not exists "z_location_mm" text,
  add column if not exists "orientation" text,
  add column if not exists "device_parameters_file" text,
  add column if not exists "notes" text;
alter table public."devices_and_supports" enable row level security;
revoke all on public."devices_and_supports" from anon, authenticated;
grant insert on public."devices_and_supports" to anon;
grant select ("device_id") on public."devices_and_supports" to anon;
drop policy if exists "devices_and_supports_insert_anon" on public."devices_and_supports";
create policy "devices_and_supports_insert_anon" on public."devices_and_supports" for insert to anon with check (true);

-- ---------- loading_histories ----------
create table if not exists public."loading_histories" (
  "loading_id" text primary key,
  "created_at" timestamptz not null default now()
);
alter table public."loading_histories"
  add column if not exists "source_id" text,
  add column if not exists "test_id" text,
  add column if not exists "device_id" text,
  add column if not exists "loading_mode" text,
  add column if not exists "loading_control_variable" text,
  add column if not exists "initial_control_variable_rate" text,
  add column if not exists "control_variable_rate_units" text,
  add column if not exists "begin_time_sec" text,
  add column if not exists "end_time_sec" text,
  add column if not exists "loading_history_file_name" text,
  add column if not exists "notes" text;
alter table public."loading_histories" enable row level security;
revoke all on public."loading_histories" from anon, authenticated;
grant insert on public."loading_histories" to anon;
grant select ("loading_id") on public."loading_histories" to anon;
drop policy if exists "loading_histories_insert_anon" on public."loading_histories";
create policy "loading_histories_insert_anon" on public."loading_histories" for insert to anon with check (true);

-- ---------- data ----------
create table if not exists public."data" (
  "data_id" text primary key,
  "created_at" timestamptz not null default now()
);
alter table public."data"
  add column if not exists "source_id" text,
  add column if not exists "test_id" text,
  add column if not exists "test_repeat_id" text,
  add column if not exists "notes" text,
  add column if not exists "source_location" text,
  add column if not exists "extraction_methods" text,
  add column if not exists "extraction_date_yyyy-mm-dd" text,
  add column if not exists "data_type" text,
  add column if not exists "number_of_specimens" text,
  add column if not exists "specimen_label" text,
  add column if not exists "device_id" text,
  add column if not exists "quantity_reported" text,
  add column if not exists "quantity_reported_type" text,
  add column if not exists "quantity_reported_mean" text,
  add column if not exists "quantity_reported_standard_deviation" text,
  add column if not exists "units" text,
  add column if not exists "x_device_id" text,
  add column if not exists "y_device_id" text,
  add column if not exists "x_quantity_reported" text,
  add column if not exists "x_quantity_reported_type" text,
  add column if not exists "y_quantity_reported" text,
  add column if not exists "y_quantity_reported_type" text,
  add column if not exists "file_name" text,
  add column if not exists "table_name" text,
  add column if not exists "table_description" text,
  add column if not exists "table_file_name" text,
  add column if not exists "name" text,
  add column if not exists "description" text,
  add column if not exists "type" text,
  add column if not exists "format" text,
  add column if not exists "filename" text;
alter table public."data" enable row level security;
revoke all on public."data" from anon, authenticated;
grant insert on public."data" to anon;
grant select ("data_id") on public."data" to anon;
drop policy if exists "data_insert_anon" on public."data";
create policy "data_insert_anon" on public."data" for insert to anon with check (true);

-- ---------- extracted_values ----------
create table if not exists public."extracted_values" (
  "record_id" text primary key,
  "created_at" timestamptz not null default now()
);
alter table public."extracted_values"
  add column if not exists "test_id" text,
  add column if not exists "related_data_id" text,
  add column if not exists "variable_name" text,
  add column if not exists "symbol" text,
  add column if not exists "value" text,
  add column if not exists "units" text,
  add column if not exists "record_origin_location" text,
  add column if not exists "extraction_method" text,
  add column if not exists "computation_formula" text,
  add column if not exists "notes" text;
alter table public."extracted_values" enable row level security;
revoke all on public."extracted_values" from anon, authenticated;
grant insert on public."extracted_values" to anon;
grant select ("record_id") on public."extracted_values" to anon;
drop policy if exists "extracted_values_insert_anon" on public."extracted_values";
create policy "extracted_values_insert_anon" on public."extracted_values" for insert to anon with check (true);

-- ---------- material_models ----------
create table if not exists public."material_models" (
  "model_id" text primary key,
  "created_at" timestamptz not null default now()
);
alter table public."material_models"
  add column if not exists "source_id" text,
  add column if not exists "model_name" text,
  add column if not exists "model_family" text,
  add column if not exists "model_role" text,
  add column if not exists "constitutive_framework" text,
  add column if not exists "dimensionality" text,
  add column if not exists "stress_state" text,
  add column if not exists "rate_dependence" text,
  add column if not exists "temperature_dependence" text,
  add column if not exists "software_or_implementation" text,
  add column if not exists "calibration_test_ids" text,
  add column if not exists "validation_test_ids" text,
  add column if not exists "equation_locations" text,
  add column if not exists "assumptions" text,
  add column if not exists "limitations" text,
  add column if not exists "review_status" text,
  add column if not exists "notes" text;
alter table public."material_models" enable row level security;
revoke all on public."material_models" from anon, authenticated;
grant insert on public."material_models" to anon;
grant select ("model_id") on public."material_models" to anon;
drop policy if exists "material_models_insert_anon" on public."material_models";
create policy "material_models_insert_anon" on public."material_models" for insert to anon with check (true);

-- ---------- model_parameters ----------
create table if not exists public."model_parameters" (
  "parameter_id" text primary key,
  "created_at" timestamptz not null default now()
);
alter table public."model_parameters"
  add column if not exists "model_id" text,
  add column if not exists "parameter_name" text,
  add column if not exists "symbol" text,
  add column if not exists "value" text,
  add column if not exists "units" text,
  add column if not exists "lower_bound" text,
  add column if not exists "upper_bound" text,
  add column if not exists "parameter_origin" text,
  add column if not exists "calibration_test_ids" text,
  add column if not exists "source_location" text,
  add column if not exists "confidence" text,
  add column if not exists "review_status" text,
  add column if not exists "notes" text;
alter table public."model_parameters" enable row level security;
revoke all on public."model_parameters" from anon, authenticated;
grant insert on public."model_parameters" to anon;
grant select ("parameter_id") on public."model_parameters" to anon;
drop policy if exists "model_parameters_insert_anon" on public."model_parameters";
create policy "model_parameters_insert_anon" on public."model_parameters" for insert to anon with check (true);

-- ---------- figures ----------
create table if not exists public."figures" (
  "figure_id" text primary key,
  "created_at" timestamptz not null default now()
);
alter table public."figures"
  add column if not exists "source_id" text,
  add column if not exists "figure_id_in_paper" text,
  add column if not exists "panel_position" text,
  add column if not exists "page" text,
  add column if not exists "caption" text,
  add column if not exists "plot_type" text,
  add column if not exists "figure_type" text,
  add column if not exists "num_curves" text,
  add column if not exists "x_label" text,
  add column if not exists "y_label" text,
  add column if not exists "x_units" text,
  add column if not exists "y_units" text,
  add column if not exists "legend_entries" text,
  add column if not exists "axis_type" text,
  add column if not exists "x_min" text,
  add column if not exists "x_max" text,
  add column if not exists "y_min" text,
  add column if not exists "y_max" text,
  add column if not exists "linked_test_ids" text,
  add column if not exists "crop_left" text,
  add column if not exists "crop_top" text,
  add column if not exists "crop_right" text,
  add column if not exists "crop_bottom" text,
  add column if not exists "crop_method" text,
  add column if not exists "digitization_confidence" text,
  add column if not exists "calibration_json" text,
  add column if not exists "calibration_method" text,
  add column if not exists "calibration_error_px" text,
  add column if not exists "extraction_method" text,
  add column if not exists "extraction_version" text,
  add column if not exists "validation_json" text,
  add column if not exists "review_status" text,
  add column if not exists "curve_data" text,
  add column if not exists "notes" text;
alter table public."figures" enable row level security;
revoke all on public."figures" from anon, authenticated;
grant insert on public."figures" to anon;
grant select ("figure_id") on public."figures" to anon;
drop policy if exists "figures_insert_anon" on public."figures";
create policy "figures_insert_anon" on public."figures" for insert to anon with check (true);
