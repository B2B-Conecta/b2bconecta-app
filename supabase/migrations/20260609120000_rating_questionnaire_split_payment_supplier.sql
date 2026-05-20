-- C4: ajuste textos cuestionario — importador valora pago del aliado; aliado valora proveedor B2B.

insert into public.platform_settings (key, value)
values (
  'rating_questionnaire_bucket_v1',
  '{
    "version": "bucket_v1",
    "scale": { "min": 1, "max": 5 },
    "questions": [
      {
        "id": "product_quality",
        "text_es": "Calidad del producto: ¿La mercancía coincide con catálogo y etiquetas?",
        "applies_to": ["aliado_rates_importer"]
      },
      {
        "id": "dispatch_time",
        "text_es": "Tiempo de despacho: ¿Cumplió tiempos de preparación y entrega?",
        "applies_to": ["aliado_rates_importer"]
      },
      {
        "id": "packaging_condition",
        "text_es": "Estado del empaque: ¿Piezas sin daños y bien embaladas?",
        "applies_to": ["aliado_rates_importer"]
      },
      {
        "id": "communication",
        "text_es": "Atención y comunicación: ¿Respuestas satisfactorias en el chat?",
        "applies_to": ["aliado_rates_importer", "importer_rates_aliado"]
      },
      {
        "id": "payment_punctuality_transparency",
        "text_es": "Puntualidad y transparencia de pago: ¿El aliado cumplió plazos y fue claro al declarar método y comprobante de pago?",
        "applies_to": ["importer_rates_aliado"]
      },
      {
        "id": "supplier_b2b_experience",
        "text_es": "Proveedor B2B: ¿Cómo valora el desempeño del importador como socio (claridad comercial, cumplimiento y trato profesional)?",
        "applies_to": ["aliado_rates_importer"]
      }
    ]
  }'::jsonb
)
on conflict (key) do update
set
  value = excluded.value,
  updated_at = now ();
