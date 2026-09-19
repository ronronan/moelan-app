use lettre::message::Mailbox;
use lettre::transport::smtp::authentication::Credentials;
use lettre::{AsyncSmtpTransport, AsyncTransport, Message, Tokio1Executor};

use crate::config::Config;

/// Generic SMTP sender, provider-agnostic on purpose (Mailgun/Brevo/SendGrid
/// all expose a plain SMTP relay) — see the M11-M16 plan. `transport` is
/// `None` when `SMTP_HOST` isn't set, which is the expected state until an
/// operator supplies real credentials: every send then just logs instead of
/// erroring, so the app runs fine without email configured.
pub struct Mailer {
    transport: Option<AsyncSmtpTransport<Tokio1Executor>>,
    from: String,
}

impl Mailer {
    pub fn new(config: &Config) -> Self {
        let transport = config.smtp_host.as_ref().map(|host| {
            let mut builder = AsyncSmtpTransport::<Tokio1Executor>::relay(host)
                .expect("invalid SMTP_HOST")
                .port(config.smtp_port);
            if !config.smtp_username.is_empty() {
                builder = builder.credentials(Credentials::new(
                    config.smtp_username.clone(),
                    config.smtp_password.clone(),
                ));
            }
            builder.build()
        });
        Self {
            transport,
            from: config.smtp_from.clone(),
        }
    }

    /// For tests that exercise `services::transactions` without wanting a
    /// real `Config` (and its required Keycloak env vars) just to get a
    /// no-op mailer.
    pub fn disabled() -> Self {
        Self {
            transport: None,
            from: String::new(),
        }
    }

    /// Never fails the caller — a broken mail provider shouldn't roll back
    /// or block the ledger write that triggered the alert. Errors (and the
    /// "not configured" case) are just logged.
    pub async fn send(&self, to: &str, subject: &str, body: String) {
        let Some(transport) = &self.transport else {
            tracing::info!(%to, %subject, "SMTP not configured, email not sent");
            return;
        };

        let to_mailbox: Mailbox = match to.parse() {
            Ok(m) => m,
            Err(err) => {
                tracing::warn!(%to, %err, "invalid recipient email, not sending");
                return;
            }
        };
        let from_mailbox: Mailbox = match self.from.parse() {
            Ok(m) => m,
            Err(err) => {
                tracing::warn!(from = %self.from, %err, "invalid SMTP_FROM, not sending");
                return;
            }
        };

        let email = match Message::builder()
            .from(from_mailbox)
            .to(to_mailbox)
            .subject(subject)
            .body(body)
        {
            Ok(email) => email,
            Err(err) => {
                tracing::warn!(%err, "failed to build email");
                return;
            }
        };

        if let Err(err) = transport.send(email).await {
            tracing::warn!(%err, "failed to send email");
        }
    }
}
