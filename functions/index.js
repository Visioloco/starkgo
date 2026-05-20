const functions = require("firebase-functions");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { MercadoPagoConfig, Preference, Payment } = require("mercadopago");

initializeApp();
const db = getFirestore();

const MP_ACCESS_TOKEN = "APP_USR-5973617015712513-042316-91c389519eea428c2e808ffa71a193a3-3354994401";

const mpClient = new MercadoPagoConfig({
  accessToken: MP_ACCESS_TOKEN,
});

const PLANES = {
  "1m": { titulo: "StarkGo · 1 Mes",    precio: 15,  meses: 1  },
  "3m": { titulo: "StarkGo · 3 Meses",  precio: 39,  meses: 3  },
  "6m": { titulo: "StarkGo · 6 Meses",  precio: 69,  meses: 6  },
  "1a": { titulo: "StarkGo · 1 Año",    precio: 120, meses: 12 },
};

exports.crearPreferenciaMercadoPago = functions.https.onCall(async (data, context) => {
  const uid = context.auth?.uid;
  if (!uid) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "El usuario debe estar autenticado para realizar esta acción"
    );
  }

  const { planId, email, nombre } = data;

  if (!planId || !email) {
    throw new functions.https.HttpsError("invalid-argument", "Faltan datos requeridos");
  }

  const plan = PLANES[planId];
  if (!plan) {
    throw new functions.https.HttpsError("invalid-argument", `Plan inválido: ${planId}`);
  }

  try {
    const preference = new Preference(mpClient);

    const body = {
      items: [
        {
          id: planId,
          title: plan.titulo,
          description: `Membresía StarkGo · ${plan.titulo}`,
          quantity: 1,
          unit_price: plan.precio,
          currency_id: "USD",
        },
      ],
      payer: {
        email: email,
        name: nombre || "",
      },
      back_urls: {
        success: "starkgo://pago/exitoso",
        failure: "starkgo://pago/fallido",
        pending: "starkgo://pago/pendiente",
      },
      auto_return: "approved",
      external_reference: uid,
      metadata: {
        uid: uid,
        planId: planId,
        meses: plan.meses,
      },
      expiration_date_to: new Date(Date.now() + 30 * 60 * 1000).toISOString(),
    };

    const result = await preference.create({ body });

    await db.collection("pagos_pendientes").add({
      uid,
      planId,
      meses: plan.meses,
      precio: plan.precio,
      preferenceId: result.id,
      estado: "pendiente",
      creadoEn: FieldValue.serverTimestamp(),
    });

    return {
      preferenceId: result.id,
      initPoint: result.init_point,
      sandboxInitPoint: result.sandbox_init_point,
    };
  } catch (error) {
    console.error("Error creando preferencia MP:", error);
    throw new functions.https.HttpsError("internal", "Error al crear el pago: " + error.message);
  }
});

exports.verificarPagoMercadoPago = functions.https.onCall(async (data, context) => {
  const uid = context.auth?.uid;
  if (!uid) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "El usuario debe estar autenticado para realizar esta acción"
    );
  }

  const { paymentId } = data;

  if (!paymentId) {
    throw new functions.https.HttpsError("invalid-argument", "Falta paymentId");
  }

  try {
    const paymentClient = new Payment(mpClient);
    const payment = await paymentClient.get({ id: paymentId });

    if (!payment || payment.status !== "approved") {
      return { aprobado: false, estado: payment?.status ?? "unknown" };
    }

    const externalRef = payment.external_reference;
    if (externalRef !== uid) {
      throw new functions.https.HttpsError("permission-denied", "El pago no corresponde a este usuario");
    }

    const planId = payment.metadata?.plan_id ?? payment.additional_info?.items?.[0]?.id;
    const meses = payment.metadata?.meses ?? PLANES[planId]?.meses ?? 1;

    const userDoc = await db.collection("user").doc(uid).get();
    const userData = userDoc.data() ?? {};
    const fechaActual = userData.fechaVencimiento?.toDate() ?? new Date();
    const base = fechaActual > new Date() ? fechaActual : new Date();
    const nuevaFecha = new Date(base);
    nuevaFecha.setMonth(nuevaFecha.getMonth() + meses);

    await db.collection("user").doc(uid).update({
      planMembresia: planId,
      mesesMembresia: meses,
      fechaVencimiento: nuevaFecha,
      activo: true,
      ultimaRenovacion: FieldValue.serverTimestamp(),
      ultimoPagoId: paymentId,
      ultimoPagoMonto: payment.transaction_amount,
    });

    const pagosSnap = await db
      .collection("pagos_pendientes")
      .where("uid", "==", uid)
      .where("estado", "==", "pendiente")
      .orderBy("creadoEn", "desc")
      .limit(1)
      .get();

    if (!pagosSnap.empty) {
      await pagosSnap.docs[0].ref.update({
        estado: "completado",
        paymentId,
        completadoEn: FieldValue.serverTimestamp(),
      });
    }

    return {
      aprobado: true,
      nuevaFecha: nuevaFecha.toISOString(),
      planId,
      meses,
    };
  } catch (error) {
    console.error("Error verificando pago:", error);
    throw new functions.https.HttpsError("internal", "Error verificando el pago: " + error.message);
  }
});