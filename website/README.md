# 🌐 60Score — Official Website & Policy Portal

This directory contains the self-contained, responsive website for **60Score**, including all mandatory legal pages required by Google Play Console.

---

## 📁 Included Pages

1. **`index.html`**: Professional landing page showcasing 60Score features, hero banner, and Google Play download link.
2. **`privacy-policy.html`**: Comprehensive, GDPR/CCPA & Google Play compliant Privacy Policy.
3. **`terms-of-service.html`**: Terms and Conditions for app usage.
4. **`data-deletion.html`**: Mandatory Google Play User Data Deletion Instructions & Request Form.
5. **`contact.html`**: Contact & Developer Support form with FAQs for scorers and tournament organizers.
6. **`assets/`**: Shared CSS stylesheet and high-resolution graphic assets.

---

## 🚀 How to Host This Website for Free (2 Minutes)

### Option 1: Free Netlify Drop (Fastest — 30 Seconds, No Code)
1. Open your browser and go to [app.netlify.com/drop](https://app.netlify.com/drop).
2. Drag and drop this entire `website/` folder directly onto the Netlify webpage.
3. You immediately get a live HTTPS URL (e.g., `https://60score-official.netlify.app/`).
4. You can use these URLs in Google Play Console:
   - **Privacy Policy URL:** `https://<your-subdomain>.netlify.app/privacy-policy.html`
   - **Data Deletion URL:** `https://<your-subdomain>.netlify.app/data-deletion.html`
   - **Website / Contact:** `https://<your-subdomain>.netlify.app/contact.html`

---

### Option 2: Free GitHub Pages (Permanent)
1. Push this folder to your GitHub repository.
2. Go to **Repository Settings > Pages**.
3. Under **Branch**, select `main` and choose the folder where your site lives, then click **Save**.
4. Your website is automatically live at:
   `https://<your-username>.github.io/<repo-name>/website/privacy-policy.html`

---

### Option 3: Free Firebase Hosting (Optional)
If you already use Firebase for 60Score:
```bash
cd website
firebase init hosting
firebase deploy --only hosting
```
