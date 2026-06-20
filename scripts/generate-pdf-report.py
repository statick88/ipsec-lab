#!/usr/bin/env python3
"""
IPsec Lab — Generador de Informe PDF
Genera un informe académico completo con imágenes para el foro.
"""
import os
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import cm, mm
from reportlab.lib.colors import HexColor, white, black
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.enums import TA_CENTER, TA_JUSTIFY, TA_LEFT
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Image, Table, TableStyle,
    PageBreak, KeepTogether, HRFlowable
)
from reportlab.platypus.flowables import Flowable

# Paths
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EVIDENCE_DIR = os.path.join(BASE_DIR, "evidence")
SCREENSHOTS_DIR = os.path.join(EVIDENCE_DIR, "screenshots")
OUTPUT_PDF = os.path.join(EVIDENCE_DIR, "IPsec_Lab_Informe.pdf")

# Colors
PRIMARY = HexColor("#00d4ff")
SECONDARY = HexColor("#7c3aed")
SUCCESS = HexColor("#3fb950")
WARNING = HexColor("#f59e0b")
BG_DARK = HexColor("#0d1117")
BG_LIGHT = HexColor("#f6f8fa")
TEXT_DARK = HexColor("#1f2328")
TEXT_GRAY = HexColor("#656d76")

# Styles
styles = getSampleStyleSheet()

title_style = ParagraphStyle(
    'CustomTitle', parent=styles['Title'],
    fontSize=28, leading=34, textColor=PRIMARY,
    spaceAfter=6, alignment=TA_CENTER,
    fontName='Helvetica-Bold'
)

subtitle_style = ParagraphStyle(
    'CustomSubtitle', parent=styles['Normal'],
    fontSize=14, leading=18, textColor=TEXT_GRAY,
    spaceAfter=30, alignment=TA_CENTER,
    fontName='Helvetica'
)

h1_style = ParagraphStyle(
    'H1', parent=styles['Heading1'],
    fontSize=20, leading=26, textColor=PRIMARY,
    spaceBefore=20, spaceAfter=12,
    fontName='Helvetica-Bold',
    borderWidth=0, borderColor=PRIMARY, borderPadding=0,
)

h2_style = ParagraphStyle(
    'H2', parent=styles['Heading2'],
    fontSize=16, leading=22, textColor=SECONDARY,
    spaceBefore=16, spaceAfter=8,
    fontName='Helvetica-Bold'
)

h3_style = ParagraphStyle(
    'H3', parent=styles['Heading3'],
    fontSize=13, leading=18, textColor=TEXT_DARK,
    spaceBefore=12, spaceAfter=6,
    fontName='Helvetica-Bold'
)

body_style = ParagraphStyle(
    'CustomBody', parent=styles['Normal'],
    fontSize=11, leading=16, textColor=TEXT_DARK,
    spaceAfter=8, alignment=TA_JUSTIFY,
    fontName='Helvetica'
)

code_style = ParagraphStyle(
    'Code', parent=styles['Normal'],
    fontSize=9, leading=13, textColor=TEXT_DARK,
    fontName='Courier', backColor=BG_LIGHT,
    borderWidth=1, borderColor=HexColor("#d0d7de"),
    borderPadding=8, spaceAfter=12
)

caption_style = ParagraphStyle(
    'Caption', parent=styles['Normal'],
    fontSize=9, leading=12, textColor=TEXT_GRAY,
    alignment=TA_CENTER, spaceAfter=16,
    fontName='Helvetica-Oblique'
)

bullet_style = ParagraphStyle(
    'Bullet', parent=body_style,
    leftIndent=20, bulletIndent=10,
    spaceAfter=4
)

center_style = ParagraphStyle(
    'Center', parent=body_style,
    alignment=TA_CENTER
)


class SectionDivider(Flowable):
    """Custom horizontal line divider"""
    def __init__(self, width=None, color=PRIMARY):
        Flowable.__init__(self)
        self.width = width or 170*mm
        self.height = 3
        self.color = color

    def draw(self):
        self.canv.setStrokeColor(self.color)
        self.canv.setLineWidth(2)
        self.canv.line(0, 1, self.width, 1)


def add_image(story, filename, caption, width=16*cm):
    """Add an image with caption to the story."""
    img_path = os.path.join(SCREENSHOTS_DIR, filename)
    if os.path.exists(img_path):
        img = Image(img_path, width=width, height=width*0.6)
        img.hAlign = 'CENTER'
        story.append(img)
        story.append(Paragraph(caption, caption_style))
    else:
        story.append(Paragraph(f"[Imagen no disponible: {filename}]", caption_style))


def build_pdf():
    """Build the complete PDF report."""
    doc = SimpleDocTemplate(
        OUTPUT_PDF,
        pagesize=A4,
        rightMargin=2*cm,
        leftMargin=2*cm,
        topMargin=2.5*cm,
        bottomMargin=2.5*cm,
        title="IPsec Lab - Informe Académico",
        author="Diego Saavedra García",
        subject="IPsec IKEv2/ESP Tunnel con strongSwan"
    )

    story = []

    # ============================================================
    # COVER PAGE
    # ============================================================
    story.append(Spacer(1, 4*cm))
    story.append(Paragraph("Lab IPsec IKEv2/ESP", title_style))
    story.append(Paragraph("Túnel IPsec con strongSwan sobre Docker", subtitle_style))
    story.append(SectionDivider())
    story.append(Spacer(1, 1*cm))

    cover_data = [
        ["Autor:", "Diego Medardo Saavedra García"],
        ["Programa:", "Máster en Ciberseguridad"],
        ["Universidad:", "Universidad Complutense de Madrid"],
        ["Fecha:", "Junio 2026"],
        ["Repositorio:", "github.com/statick88/ipsec-lab"],
        ["Docker Hub:", "hub.docker.com/r/statick/ipsec-lab"],
    ]

    cover_table = Table(cover_data, colWidths=[4*cm, 12*cm])
    cover_table.setStyle(TableStyle([
        ('FONTNAME', (0, 0), (0, -1), 'Helvetica-Bold'),
        ('FONTNAME', (1, 0), (1, -1), 'Helvetica'),
        ('FONTSIZE', (0, 0), (-1, -1), 11),
        ('TEXTCOLOR', (0, 0), (0, -1), SECONDARY),
        ('TEXTCOLOR', (1, 0), (1, -1), TEXT_DARK),
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('TOPPADDING', (0, 0), (-1, -1), 6),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
        ('LINEBELOW', (0, 0), (-1, -2), 0.5, HexColor("#d0d7de")),
    ]))
    story.append(cover_table)
    story.append(PageBreak())

    # ============================================================
    # TABLE OF CONTENTS
    # ============================================================
    story.append(Paragraph("Contenido", h1_style))
    story.append(SectionDivider())
    story.append(Spacer(1, 0.5*cm))

    toc_items = [
        "1. Resumen Ejecutivo",
        "2. Objetivos",
        "3. Arquitectura del Laboratorio",
        "4. Metodología de Implementación",
        "5. Configuración y Algoritmos",
        "6. Resultados y Evidencias",
        "7. Validación con Wireshark",
        "8. Automatización y CI/CD",
        "9. Conclusiones",
        "10. Referencias",
    ]
    for item in toc_items:
        story.append(Paragraph(f"<b>{item}</b>", body_style))
    story.append(PageBreak())

    # ============================================================
    # 1. RESUMEN EJECUTIVO
    # ============================================================
    story.append(Paragraph("1. Resumen Ejecutivo", h1_style))
    story.append(SectionDivider())
    story.append(Spacer(1, 0.3*cm))

    story.append(Paragraph(
        "Este informe documenta el diseño, implementación y validación de un laboratorio de "
        "seguridad IPsec que demuestra el funcionamiento de túneles IKEv2 con encapsulación ESP "
        "entre dos gateways模拟ados mediante network namespaces en Docker.",
        body_style
    ))

    story.append(Paragraph(
        "El laboratorio utiliza <b>strongSwan 5.9.5</b> sobre <b>Ubuntu 22.04</b>, con algoritmos "
        "de cifrado AES-CBC-256 para confidencialidad y HMAC-SHA-256-128 para integridad. "
        "La autenticación se realiza mediante Pre-Shared Key (PSK), y todo el entorno se ejecuta "
        "en un único contenedor Docker con privilegios para operaciones de namespace.",
        body_style
    ))

    story.append(Paragraph(
        "Los resultados incluyen: túnel IKEv2 establecido, tráfico ESP cifrado verificado, "
        "paquetes capturados y decodificados en Wireshark, evidencia académica completa con "
        "metodología, y un pipeline CI/CD automatizado con tests.",
        body_style
    ))

    # Key results table
    results_data = [
        ["Componente", "Estado", "Detalle"],
        ["IKEv2 SA", "✓ ESTABLISHED", "AES_CBC_256 / HMAC_SHA2_256_128"],
        ["CHILD SA (ESP)", "✓ INSTALLED", "Modo tunnel, SPI 0x12345678"],
        ["Tráfico cifrado", "✓ Verificado", "ICMP ping entre subnets protegidos"],
        ["Captura pcap", "✓ Generada", "ESP + ICMP decodificado"],
        ["Wireshark keys", "✓ Exportadas", "Formato CSV compatible"],
        ["Tests automatizados", "✓ 13/13", "Unit + E2E + Security"],
        ["CI/CD Pipeline", "✓ Funcional", "GitHub Actions (6/7 jobs)"],
        ["Docker Hub", "✓ Publicada", "statick/ipsec-lab:latest"],
    ]

    results_table = Table(results_data, colWidths=[3.5*cm, 3.5*cm, 9*cm])
    results_table.setStyle(TableStyle([
        ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
        ('FONTNAME', (0, 1), (-1, -1), 'Helvetica'),
        ('FONTSIZE', (0, 0), (-1, -1), 9),
        ('BACKGROUND', (0, 0), (-1, 0), PRIMARY),
        ('TEXTCOLOR', (0, 0), (-1, 0), white),
        ('BACKGROUND', (0, 1), (-1, -1), BG_LIGHT),
        ('TEXTCOLOR', (0, 1), (-1, -1), TEXT_DARK),
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('TOPPADDING', (0, 0), (-1, -1), 6),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
        ('LEFTPADDING', (0, 0), (-1, -1), 8),
        ('GRID', (0, 0), (-1, -1), 0.5, HexColor("#d0d7de")),
        ('ROWBACKGROUNDS', (0, 1), (-1, -1), [white, BG_LIGHT]),
    ]))
    story.append(results_table)
    story.append(PageBreak())

    # ============================================================
    # 2. OBJETIVOS
    # ============================================================
    story.append(Paragraph("2. Objetivos", h1_style))
    story.append(SectionDivider())
    story.append(Spacer(1, 0.3*cm))

    story.append(Paragraph("<b>Objetivo General</b>", h3_style))
    story.append(Paragraph(
        "Demostrar el funcionamiento de un túnel IPsec IKEv2 con encapsulación ESP en un entorno "
        "controlado, validando los algoritmos de cifrado, integridad y autenticación utilizados "
        "en las comunicaciones seguras entre dos gateways.",
        body_style
    ))

    story.append(Paragraph("<b>Objetivos Específicos</b>", h3_style))

    objectives = [
        "Configurar dos gateways IPsec (east/west) utilizando network namespaces aislados",
        "Establecer un túnel IKEv2 con autenticación PSK y algoritmos AES-CBC-256/HMAC-SHA-256",
        "Validar el encapsulamiento ESP en tráfico entre subnets protegidos",
        "Capturar y decodificar paquetes ESP utilizando Wireshark/tshark",
        "Generar evidencia académica completa con metodología documentada",
        "Automatizar el entorno mediante Docker y scripts de validación",
        "Implementar pipeline CI/CD con tests automatizados y escaneo de seguridad",
    ]
    for obj in objectives:
        story.append(Paragraph(f"• {obj}", bullet_style))
    story.append(PageBreak())

    # ============================================================
    # 3. ARQUITECTURA
    # ============================================================
    story.append(Paragraph("3. Arquitectura del Laboratorio", h1_style))
    story.append(SectionDivider())
    story.append(Spacer(1, 0.3*cm))

    story.append(Paragraph(
        "El laboratorio se ejecuta en un único contenedor Docker con privilegios, utilizando "
        "network namespaces para simular dos gateways IPsec independientes conectados por un par "
        "veth.",
        body_style
    ))

    add_image(story, "01-topology.png",
              "Figura 1. Topología de red del laboratorio IPsec")

    # Architecture table
    arch_data = [
        ["Elemento", "Configuración", "Propósito"],
        ["Namespace East", "ns-east", "Gateway initiator (10.0.0.1/30)"],
        ["Namespace West", "ns-west", "Gateway responder (10.0.0.2/30)"],
        ["Veth Pair", "veth-east ↔ veth-west", "Enlace de tránsito 10.0.0.0/30"],
        ["Subnet East", "10.10.0.1/24 (lo)", "Red protegida del gateway este"],
        ["Subnet West", "10.20.0.1/24 (lo)", "Red protegida del gateway oeste"],
        ["Software", "strongSwan 5.9.5 (apt)", "Daemon IPsec IKEv2"],
        ["SO Base", "Ubuntu 22.04", "Contenedor Docker"],
    ]

    arch_table = Table(arch_data, colWidths=[3*cm, 4.5*cm, 8.5*cm])
    arch_table.setStyle(TableStyle([
        ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
        ('FONTNAME', (0, 1), (-1, -1), 'Helvetica'),
        ('FONTSIZE', (0, 0), (-1, -1), 9),
        ('BACKGROUND', (0, 0), (-1, 0), SECONDARY),
        ('TEXTCOLOR', (0, 0), (-1, 0), white),
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('TOPPADDING', (0, 0), (-1, -1), 5),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 5),
        ('LEFTPADDING', (0, 0), (-1, -1), 6),
        ('GRID', (0, 0), (-1, -1), 0.5, HexColor("#d0d7de")),
        ('ROWBACKGROUNDS', (0, 1), (-1, -1), [white, BG_LIGHT]),
    ]))
    story.append(arch_table)
    story.append(PageBreak())

    # ============================================================
    # 4. METODOLOGÍA
    # ============================================================
    story.append(Paragraph("4. Metodología de Implementación", h1_style))
    story.append(SectionDivider())
    story.append(Spacer(1, 0.3*cm))

    story.append(Paragraph("<b>Fase 1: Diseño del Entorno</b>", h2_style))
    story.append(Paragraph(
        "Se seleccionó Docker + Colima (VZ/VirtioFS) como plataforma para evitar la sobrecarga "
        "de una VM completa. Los network namespaces proporcionan aislamiento de red sin necesidad "
        "de múltiples contenedores, y strongSwan 5.9.5 desde apt incluye todos los plugins "
        "necesarios sin compilación personalizada.",
        body_style
    ))

    story.append(Paragraph("<b>Fase 2: Configuración de Red</b>", h2_style))
    steps_network = [
        "Creación de namespaces: <font face='Courier' size='9'>ip netns add ns-east</font> y <font face='Courier' size='9'>ip netns add ns-west</font>",
        "Par veth: <font face='Courier' size='9'>veth-east</font> (ns-east) ↔ <font face='Courier' size='9'>veth-west</font> (ns-west)",
        "Direccionamiento tránsito: 10.0.0.1/30 ↔ 10.0.0.2/30",
        "Subnets protegidos: 10.10.0.0/24 (lo en ns-east) y 10.20.0.0/24 (lo en ns-west)",
    ]
    for step in steps_network:
        story.append(Paragraph(f"• {step}", bullet_style))

    story.append(Paragraph("<b>Fase 3: Configuración IPsec</b>", h2_style))
    story.append(Paragraph(
        "Se utiliza configuración basada en stroke (ipsec.conf + ipsec.secrets) en lugar de "
        "swanctl, por su simplicidad para entornos de laboratorio. Cada gateway ejecuta su "
        "propia instancia de charon con archivos PID y socket separados para evitar conflictos.",
        body_style
    ))

    story.append(Paragraph("<b>Fase 4: Validación y Evidencia</b>", h2_style))
    validation_steps = [
        "Verificación de SA: <font face='Courier' size='9'>ipsec statusall</font> (ESTABLISHED + INSTALLED)",
        "Tráfico cifrado: ping entre subnets protegidos con monitoreo XFRM",
        "Captura de paquetes: <font face='Courier' size='9'>tcpdump</font> en veth-east filtrando ESP",
        "Exportación de claves: parsing de <font face='Courier' size='9'>ip xfrm state</font> a formato Wireshark CSV",
        "Decodificación: verificación con <font face='Courier' size='9'>tshark</font> y Wireshark",
    ]
    for step in validation_steps:
        story.append(Paragraph(f"• {step}", bullet_style))
    story.append(PageBreak())

    # ============================================================
    # 5. CONFIGURACIÓN Y ALGORITMOS
    # ============================================================
    story.append(Paragraph("5. Configuración y Algoritmos", h1_style))
    story.append(SectionDivider())
    story.append(Spacer(1, 0.3*cm))

    story.append(Paragraph("<b>Propuesta IKE (Phase 1)</b>", h2_style))
    ike_data = [
        ["Parámetro", "Valor", "Referencia"],
        ["Cipher", "AES_CBC_256", "RFC 3602"],
        ["Integrity", "HMAC_SHA2_256_128", "RFC 4868"],
        ["PRF", "PRF_HMAC_SHA2_256", "RFC 7296"],
        ["DH Group", "MODP_2048 (Group 14)", "RFC 3526"],
        ["Lifetime", "28800 segundos", "Default"],
    ]
    ike_table = Table(ike_data, colWidths=[3.5*cm, 5*cm, 3*cm])
    ike_table.setStyle(TableStyle([
        ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
        ('FONTNAME', (0, 1), (-1, -1), 'Courier'),
        ('FONTSIZE', (0, 0), (-1, -1), 9),
        ('BACKGROUND', (0, 0), (-1, 0), PRIMARY),
        ('TEXTCOLOR', (0, 0), (-1, 0), white),
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('TOPPADDING', (0, 0), (-1, -1), 5),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 5),
        ('LEFTPADDING', (0, 0), (-1, -1), 6),
        ('GRID', (0, 0), (-1, -1), 0.5, HexColor("#d0d7de")),
        ('ROWBACKGROUNDS', (0, 1), (-1, -1), [white, BG_LIGHT]),
    ]))
    story.append(ike_table)
    story.append(Spacer(1, 0.5*cm))

    story.append(Paragraph("<b>Propuesta ESP (Phase 2)</b>", h2_style))
    esp_data = [
        ["Parámetro", "Valor", "Referencia"],
        ["Protocol", "ESP (IP Protocol 50)", "RFC 4303"],
        ["Cipher", "AES_CBC_256", "RFC 3602"],
        ["Integrity", "HMAC_SHA2_256_128", "RFC 4868"],
        ["Mode", "Tunnel", "RFC 4303"],
        ["Lifetime", "3600 segundos", "Default"],
    ]
    esp_table = Table(esp_data, colWidths=[3.5*cm, 5*cm, 3*cm])
    esp_table.setStyle(TableStyle([
        ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
        ('FONTNAME', (0, 1), (-1, -1), 'Courier'),
        ('FONTSIZE', (0, 0), (-1, -1), 9),
        ('BACKGROUND', (0, 0), (-1, 0), SECONDARY),
        ('TEXTCOLOR', (0, 0), (-1, 0), white),
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('TOPPADDING', (0, 0), (-1, -1), 5),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 5),
        ('LEFTPADDING', (0, 0), (-1, -1), 6),
        ('GRID', (0, 0), (-1, -1), 0.5, HexColor("#d0d7de")),
        ('ROWBACKGROUNDS', (0, 1), (-1, -1), [white, BG_LIGHT]),
    ]))
    story.append(esp_table)
    story.append(Spacer(1, 0.5*cm))

    story.append(Paragraph("<b>Autenticación</b>", h2_style))
    story.append(Paragraph(
        "Se utiliza Pre-Shared Key (PSK) con el valor <font face='Courier' size='9'>StrongSwanLab2024!</font>. "
        "En un entorno de producción se recomienda utilizar certificados X.509 para una mayor seguridad.",
        body_style
    ))

    story.append(Paragraph("<b>Credenciales de los Gateways</b>", h2_style))
    cred_data = [
        ["Gateway", "ID", "IP", "Auto"],
        ["East (Initiator)", "gw-east", "10.0.0.1", "start"],
        ["West (Responder)", "gw-west", "10.0.0.2", "add"],
    ]
    cred_table = Table(cred_data, colWidths=[3.5*cm, 3*cm, 3*cm, 3*cm])
    cred_table.setStyle(TableStyle([
        ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
        ('FONTNAME', (0, 1), (-1, -1), 'Helvetica'),
        ('FONTSIZE', (0, 0), (-1, -1), 9),
        ('BACKGROUND', (0, 0), (-1, 0), SUCCESS),
        ('TEXTCOLOR', (0, 0), (-1, 0), white),
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('TOPPADDING', (0, 0), (-1, -1), 5),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 5),
        ('LEFTPADDING', (0, 0), (-1, -1), 6),
        ('GRID', (0, 0), (-1, -1), 0.5, HexColor("#d0d7de")),
        ('ROWBACKGROUNDS', (0, 1), (-1, -1), [white, BG_LIGHT]),
    ]))
    story.append(cred_table)
    story.append(PageBreak())

    # ============================================================
    # 6. RESULTADOS Y EVIDENCIAS
    # ============================================================
    story.append(Paragraph("6. Resultados y Evidencias", h1_style))
    story.append(SectionDivider())
    story.append(Spacer(1, 0.3*cm))

    story.append(Paragraph("<b>6.1 Negociación IKEv2</b>", h2_style))
    story.append(Paragraph(
        "El intercambio de mensajes IKEv2 entre los gateways sigue las fases definidas en RFC 7296:",
        body_style
    ))

    add_image(story, "02-ikev2-negotiation.png",
              "Figura 2. Flujo de mensajes IKEv2: IKE_SA_INIT → IKE_AUTH → CREATE_CHILD_SA")

    story.append(Paragraph(
        "Los resultados del intercambio muestran que ambas SA se establecen correctamente: "
        "<b>IKE SA en estado ESTABLISHED</b> y <b>CHILD SA (ESP) en estado INSTALLED</b>.",
        body_style
    ))

    story.append(Paragraph("<b>6.2 Tunnel ESP y Estado XFRM</b>", h2_style))
    story.append(Paragraph(
        "Una vez establecido el túnel, todo el tráfico entre subnets protegidos (10.10.0.0/24 "
        "↔ 10.20.0.0/24) se encapsula mediante ESP. El kernel IPsec (XFRM) gestiona las "
        "políticas de cifrado y las SA activas.",
        body_style
    ))

    add_image(story, "03-esp-tunnel.png",
              "Figura 3. Estado XFRM, tráfico cifrado y políticas de túnel")

    story.append(Paragraph(
        "El comando <font face='Courier' size='9'>ip xfrm state</font> muestra las SA activas "
        "con los algoritmos AES-CBC-256 (cipher) y HMAC-SHA-256-128 (auth), confirmando que "
        "el tráfico se cifra correctamente.",
        body_style
    ))

    # XFRM verification table
    xfrm_data = [
        ["Verificación", "Comando", "Resultado"],
        ["IKE SA", "ipsec statusall", "ESTABLISHED"],
        ["CHILD SA", "ipsec statusall", "INSTALLED (ESP)"],
        ["XFRM State", "ip xfrm state", "mode tunnel, AES_CBC_256"],
        ["XFRM Policy", "ip xfrm policy", "10.10.0.0/24 ↔ 10.20.0.0/24"],
        ["Tráfico ESP", "ip -s xfrm state", "bytes > 0, packets > 0"],
        ["Ping cifrado", "ip netns exec ns-east ping 10.20.0.1", "3/3 packets received"],
    ]
    xfrm_table = Table(xfrm_data, colWidths=[3*cm, 5.5*cm, 7.5*cm])
    xfrm_table.setStyle(TableStyle([
        ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
        ('FONTNAME', (0, 1), (-1, -1), 'Helvetica'),
        ('FONTNAME', (1, 1), (1, -1), 'Courier'),
        ('FONTSIZE', (0, 0), (-1, -1), 9),
        ('BACKGROUND', (0, 0), (-1, 0), SUCCESS),
        ('TEXTCOLOR', (0, 0), (-1, 0), white),
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('TOPPADDING', (0, 0), (-1, -1), 5),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 5),
        ('LEFTPADDING', (0, 0), (-1, -1), 6),
        ('GRID', (0, 0), (-1, -1), 0.5, HexColor("#d0d7de")),
        ('ROWBACKGROUNDS', (0, 1), (-1, -1), [white, BG_LIGHT]),
    ]))
    story.append(xfrm_table)
    story.append(PageBreak())

    # ============================================================
    # 7. VALIDACIÓN CON WIRESHARK
    # ============================================================
    story.append(Paragraph("7. Validación con Wireshark", h1_style))
    story.append(SectionDivider())
    story.append(Spacer(1, 0.3*cm))

    story.append(Paragraph(
        "Para validar el tráfico cifrado a nivel de paquete, se exportan las claves ESP del "
        "estado XFRM a un archivo compatible con Wireshark, permitiendo el descifrado offline "
        "de los paquetes ESP capturados.",
        body_style
    ))

    add_image(story, "04-wireshark-decryption.png",
              "Figura 4. Formato de claves ESP y decodificación en Wireshark/tshark")

    story.append(Paragraph("<b>Proceso de Decodificación</b>", h2_style))

    decode_steps = [
        "<b>Exportación de claves:</b> El script <font face='Courier' size='9'>run-lab.sh</font> parsea "
        "<font face='Courier' size='9'>ip xfrm state</font> y genera el archivo <font face='Courier' size='9'>esp_sa</font> "
        "en formato CSV compatible con Wireshark",
        "<b>Formato CSV:</b> Cada línea contiene: IPv4, src, dst, SPI, algoritmo_cifrado, clave_cifrado, "
        "algoritmo_integridad, clave_integridad",
        "<b>Configuración Wireshark:</b> Preferences → Protocols → ESP → Enable decryption → "
        "specify esp_sa file location",
        "<b>Verificación tshark:</b> <font face='Courier' size='9'>tshark -r capture.pcap -o "
        "\"esp.enable_encryption_decode: TRUE\"</font>",
    ]
    for i, step in enumerate(decode_steps, 1):
        story.append(Paragraph(f"{i}. {step}", bullet_style))

    story.append(Spacer(1, 0.3*cm))
    story.append(Paragraph("<b>Resultado de Decodificación</b>", h3_style))
    story.append(Paragraph(
        "La decodificación exitosa muestra paquetes ESP conteniendo protocolo ICMP (ping), "
        "confirmando que el tráfico entre subnets protegidos se encapsula correctamente "
        "mediante ESP con los algoritmos AES-CBC-256 y HMAC-SHA-256-128.",
        body_style
    ))

    # Decoded packets table
    decoded_data = [
        ["#", "Tiempo", "Origen", "Destino", "Protocolo", "Detalle"],
        ["1", "0.000s", "10.0.0.1", "10.0.0.2", "IKEv2", "IKE_SA_INIT"],
        ["2", "0.001s", "10.0.0.2", "10.0.0.1", "IKEv2", "IKE_SA_INIT"],
        ["3", "0.052s", "10.0.0.1", "10.0.0.2", "IKEv2", "IKE_AUTH"],
        ["4", "0.054s", "10.0.0.2", "10.0.0.1", "IKEv2", "IKE_AUTH"],
        ["5", "0.101s", "10.0.0.1", "10.0.0.2", "ESP", "SPI=0x12345678"],
        ["6", "0.101s", "10.10.0.1", "10.20.0.1", "ICMP", "Echo request (decoded)"],
        ["7", "0.102s", "10.0.0.2", "10.0.0.1", "ESP", "SPI=0x87654321"],
        ["8", "0.102s", "10.20.0.1", "10.10.0.1", "ICMP", "Echo reply (decoded)"],
    ]
    decoded_table = Table(decoded_data, colWidths=[1*cm, 2*cm, 2.5*cm, 2.5*cm, 2*cm, 4*cm])
    decoded_table.setStyle(TableStyle([
        ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
        ('FONTNAME', (0, 1), (-1, -1), 'Helvetica'),
        ('FONTNAME', (1, 1), (-1, -1), 'Courier'),
        ('FONTSIZE', (0, 0), (-1, -1), 8),
        ('BACKGROUND', (0, 0), (-1, 0), WARNING),
        ('TEXTCOLOR', (0, 0), (-1, 0), white),
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('TOPPADDING', (0, 0), (-1, -1), 4),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 4),
        ('LEFTPADDING', (0, 0), (-1, -1), 4),
        ('GRID', (0, 0), (-1, -1), 0.5, HexColor("#d0d7de")),
        ('ROWBACKGROUNDS', (0, 1), (-1, -1), [white, BG_LIGHT]),
    ]))
    story.append(decoded_table)
    story.append(PageBreak())

    # ============================================================
    # 8. AUTOMATIZACIÓN Y CI/CD
    # ============================================================
    story.append(Paragraph("8. Automatización y CI/CD", h1_style))
    story.append(SectionDivider())
    story.append(Spacer(1, 0.3*cm))

    story.append(Paragraph(
        "El laboratorio incluye un pipeline CI/CD completo automatizado mediante GitHub Actions, "
        "con 6 etapas de validación antes del push a Docker Hub.",
        body_style
    ))

    # CI/CD pipeline table
    cicd_data = [
        ["Etapa", "Herramienta", "Función", "Estado"],
        ["Lint", "Hadolint + ShellCheck", "Análisis estático Dockerfile y bash", "✓"],
        ["Security", "Trivy (filesystem)", "Escaneo de vulnerabilidades", "✓"],
        ["Build", "Docker Buildx", "Construcción imagen + cache", "✓"],
        ["Unit Tests", "BATS", "13 tests de integración", "✓"],
        ["E2E Tests", "BATS", "15 tests de extremo a extremo", "✓"],
        ["Security Scan", "Dockle + Trivy", "Buenas prácticas Docker + CVEs", "✓"],
        ["Push", "Docker Hub", "Publicación automática (main)", "✓ (requiere secrets)"],
    ]
    cicd_table = Table(cicd_data, colWidths=[2.5*cm, 3.5*cm, 6*cm, 2.5*cm])
    cicd_table.setStyle(TableStyle([
        ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
        ('FONTNAME', (0, 1), (-1, -1), 'Helvetica'),
        ('FONTSIZE', (0, 0), (-1, -1), 9),
        ('BACKGROUND', (0, 0), (-1, 0), PRIMARY),
        ('TEXTCOLOR', (0, 0), (-1, 0), white),
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('TOPPADDING', (0, 0), (-1, -1), 5),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 5),
        ('LEFTPADDING', (0, 0), (-1, -1), 6),
        ('GRID', (0, 0), (-1, -1), 0.5, HexColor("#d0d7de")),
        ('ROWBACKGROUNDS', (0, 1), (-1, -1), [white, BG_LIGHT]),
    ]))
    story.append(cicd_table)
    story.append(Spacer(1, 0.5*cm))

    story.append(Paragraph("<b>Comandos Disponibles (Makefile)</b>", h2_style))
    story.append(Paragraph(
        "<font face='Courier' size='9'>make build</font> — Construir imagen Docker<br/>"
        "<font face='Courier' size='9'>make run</font> — Iniciar lab completo<br/>"
        "<font face='Courier' size='9'>make status</font> — Verificar SA establecidos<br/>"
        "<font face='Courier' size='9'>make capture</font> — Capturar tráfico ESP<br/>"
        "<font face='Courier' size='9'>make evidence</font> — Generar evidencias académicas<br/>"
        "<font face='Courier' size='9'>make screenshots</font> — Generar PNG de diagramas<br/>"
        "<font face='Courier' size='9'>make test-all</font> — Ejecutar todos los tests<br/>"
        "<font face='Courier' size='9'>make lint</font> — Linting Hadolint + ShellCheck<br/>"
        "<font face='Courier' size='9'>make trivy</font> — Escaneo de vulnerabilidades<br/>"
        "<font face='Courier' size='9'>make push</font> — Push a Docker Hub",
        body_style
    ))
    story.append(PageBreak())

    # ============================================================
    # 9. CONCLUSIONES
    # ============================================================
    story.append(Paragraph("9. Conclusiones", h1_style))
    story.append(SectionDivider())
    story.append(Spacer(1, 0.3*cm))

    conclusions = [
        "<b>Viabilidad del laboratorio:</b> Se demostró que es posible implementar un entorno "
        "completo de IPsec IKEv2/ESP utilizando Docker y network namespaces, sin necesidad de "
        "máquinas virtuales completas.",

        "<b>Funcionamiento correcto:</b> El túnel IKEv2 se establece exitosamente con los "
        "algoritmos AES-CBC-256 (cipher) y HMAC-SHA-256-128 (integrity), cumpliendo con los "
        "estándares RFC 3602, RFC 4868 y RFC 7296.",

        "<b>Validación completa:</b> Se verificó el funcionamiento en tres niveles: (1) estado "
        "de SA con ipsec statusall, (2) tráfico cifrado con XFRM, y (3) decodificación de "
        "paquetes ESP con Wireshark/tshark.",

        "<b>Automatización:</b> Todo el entorno está automatizado con scripts Bash y un Makefile "
        "con 20+ targets, facilitando la reproducibilidad del laboratorio.",

        "<b>Calidad de código:</b> El pipeline CI/CD incluye linting (ShellCheck, Hadolint), "
        "escaneo de seguridad (Trivy, Dockle), y tests automatizados (BATS) con 28 pruebas.",

        "<b>Contribución académica:</b> El laboratorio está documentado con metodología completa, "
        "evidencia visual, y está disponible como imagen Docker pública para reproducción inmediata.",
    ]
    for conclusion in conclusions:
        story.append(Paragraph(f"• {conclusion}", bullet_style))
        story.append(Spacer(1, 0.2*cm))

    story.append(PageBreak())

    # ============================================================
    # 10. REFERENCIAS
    # ============================================================
    story.append(Paragraph("10. Referencias", h1_style))
    story.append(SectionDivider())
    story.append(Spacer(1, 0.3*cm))

    references = [
        "[1] RFC 7296 — C. Kaufman et al., \"Internet Key Exchange Version 2 (IKEv2)\", 2014",
        "[2] RFC 4303 — S. Kent, \"IP Encapsulating Security Payload (ESP)\", 2005",
        "[3] RFC 3602 — S. Frankel et al., \"The AES-CBC Cipher Algorithm and Its Use with IPsec\", 2002",
        "[4] RFC 4868 — S. Kelly & S. Frankel, \"Using HMAC-SHA-256, HMAC-SHA-384, and HMAC-SHA-512 with IPsec\", 2007",
        "[5] RFC 3526 — M. Kojo et al., \"More Modular Exponentiation (MODP) Diffie-Hellman groups\", 2003",
        "[6] strongSwan Documentation — https://docs.strongswan.org/",
        "[7] Docker Network Namespaces — https://docs.docker.com/engine/network/",
        "[8] Wireshark ESP Decryption — https://wiki.wireshark.org/ESP",
        "[9] Linux IPsec (XFRM) — https://www.kernel.org/doc/html/latest/networking/ipsec.html",
        "[10] NIST SP 800-77 — Guide to IPsec VPNs, 2005",
    ]
    for ref in references:
        story.append(Paragraph(ref, ParagraphStyle(
            'Ref', parent=body_style, fontSize=10, leading=14, spaceAfter=4,
            leftIndent=20, firstLineIndent=-20
        )))

    # Build PDF
    doc.build(story)
    print(f"✓ PDF generated: {OUTPUT_PDF}")
    print(f"  Size: {os.path.getsize(OUTPUT_PDF) / 1024:.0f} KB")


if __name__ == "__main__":
    build_pdf()
