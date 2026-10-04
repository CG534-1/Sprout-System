import { writeFileSync } from 'fs';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';

const apiKey = process.env.FIREBASE_API_KEY ?? '';
const appId = process.env.FIREBASE_APP_ID ?? '';
const senderId = process.env.FIREBASE_MESSAGING_SENDER_ID ?? '';
const projectId = process.env.FIREBASE_PROJECT_ID ?? '';
const out = join(dirname(fileURLToPath(import.meta.url)), '../frontend/android/app/google-services.json');

if (!apiKey || !appId || !senderId || !projectId) {
  process.exit(0);
}

writeFileSync(
  out,
  `${JSON.stringify(
    {
      project_info: {
        project_number: senderId,
        project_id: projectId,
        storage_bucket: `${projectId}.firebasestorage.app`,
      },
      client: [
        {
          client_info: {
            mobilesdk_app_id: appId,
            android_client_info: {
              package_name: 'com.sprout.care.sprout',
            },
          },
          oauth_client: [],
          api_key: [{ current_key: apiKey }],
          services: {
            appinvite_service: {
              other_platform_oauth_client: [],
            },
          },
        },
      ],
      configuration_version: '1',
    },
    null,
    2,
  )}\n`,
);
