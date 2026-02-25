CREATE OR REPLACE FUNCTION "public"."handle_new_user"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$BEGIN
  INSERT INTO public.profile (auth_id, username, is_youth, parent_profile_id)
  VALUES (NEW.id, NULL, false, NULL)
  ON CONFLICT (auth_id) DO NOTHING;

  INSERT INTO public.stripe (auth_id, onboarded)
  VALUES (NEW.id, false)
  ON CONFLICT (auth_id) DO NOTHING;

  INSERT INTO public.wallet (auth_id, flow_address, flow_private_key, flow_public_key)
  VALUES (NEW.id, NULL, NULL, NULL)
  ON CONFLICT (auth_id) DO NOTHING;

  RETURN NEW;
END;$$;
