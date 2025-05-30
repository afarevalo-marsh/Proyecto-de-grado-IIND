# -----------------------------------------------------------
# Sección 1: Preparación de datos
# -----------------------------------------------------------

# Limpiar el entorno
rm(list = ls())

## Librerias ------------------
library(pacman)
library(tidyverse) # Paquete grande de manipulacion
library(lubridate) # Paquete para manejo de fechas
library(skimr)     # Paquete para revision de datos
library(stargazer) # Paquete de tablas "bonitas", regs y estad desc
library(dplyr)     # Paquete parte de tidyverse donde esta mutate, select, filter, summarise...
library(rio)       # Paquete de importacion/exportacion de datos
library(gridExtra)
library(patchwork)
library(stats)
library(readxl)
library(writexl)
library(ggplot2)
library(officer)
library(flextable)
library(pscl)
library(corrplot)   # Para el gráfico de correlación
library(devtools)
library(fpp3)
library(urca)
library(vars)
library(MTS)
library(tseries) # Importamos la librería de tserires para la aplicación de la prueba de Dickey Fuller.

# Manejo del directorio
getwd()
directorio <- "C:/Users/windows/Documents/GitHub/Problem_Set_1/Proyecto-de-grado-IIND/Proyecto de grado IIND/1. Datos"
setwd(directorio)

# Chequeo de los archivos del directorio
dir()
list.files()

## Importacion de los datos ------------------
install_formats() # Cuestiones de importacion de archivos del paquete rio
da <- import("7. Bogota_Promedio_Dias_Act_VECM.xlsx")

# Convertir la base de datos "da" a formato ts
da.ts <- ts(da[2:6], start = as.Date(2021), frequency = 365)
plot(da.ts)
str(da.ts)

# -----------------------------------------------------------
# Sección 2: Identificación nivel regresivo y prueba de cointegración
# -----------------------------------------------------------

# Evaluará modelos VAR con hasta 7 retardos.
nivelka=VARselect(da.ts, lag.max = 7, type = "const")
nivelka$selection

# AIC(n)  HQ(n)  SC(n) FPE(n) 
#   7      4      3      7 

# Aplicamos la prueba de Johansen para la identificación de relaciones lineales
# entre las series, lo que nos indica la condición de cointegración.
johatest=ca.jo(da.ts, type = "trace", K=7, ecdet ="none", spec = "longrun")
summary(johatest)

# r = 0  | 308.12 66.49 70.60 78.87
# Como 308.12 > ... , el rango de la martiz es 0 entonces si estan cointegradas,
# Si hay un equilibrio a largo plazo.

# -----------------------------------------------------------
# Sección 3: Diferenciación de las series
# -----------------------------------------------------------
  
adf.test(da[,2])
adf.test(da[,3])
adf.test(da[,4])
adf.test(da[,5])
adf.test(da[,6])

# Esto significa que hay suficiente evidencia estadística para decir que la serie es estacionaria.

# -----------------------------------------------------------
# Sección 4: Modelación con librería vars
# -----------------------------------------------------------

# A. Selección orden regresivo

# En la librería de VAR, la función que permite identificar el orden regresivo es la función de VARselect(). Se elige el máximo de rezagos de lag.max=7.
nivelk=VARselect(da.ts, lag.max = 7, type = "const")
nivelk$selection

# B: Regresión VAR.
#Podemos volver a llamar la librería de vars y aplicar el regresión habiendo encontrado que p=2.
library(vars)
m0=vars::VAR(da.ts, p=7)
summary(m0)

# El PM25 depende de si mismo, radsolar, o3 y ws, marginalmente no depende.  

# -----------------------------------------------------------
# Sección 5: Modelación con libreria MTS
# -----------------------------------------------------------

# A. Selección del orden regresivo

# En la librería de MTS, la función que permite la identificación del nivel regresivo es la de VARorder().
VARorder(da.ts)
# Un nivel regresivo de 5, pues es donde cambia el Pvalue ***

# B. Regresión VAR

#Ahora, aplicamos la función de VAR, para generar el modelo de regresión:
m1=MTS::VAR(da.ts,5)

#Separemos primero los residuales del modelo de regresión y apliquemos la función de mq() para la revisión de la calidad del modelo.
#Indicamos los grados de libertad del modelo, que son 18 (2 matrices autorregresivas de 9 coeficientes, cada uno, mas 3 ordenadas).
resi=m1$residuals
mq(resi, adj=21)
# Los Pvalues son muy altos, es un buen modelo

#Podemos igualmente visualizar los rezagos de los residuales, en búsuqueda de rezagos no capturados por el modelo.
acf(resi)

# C. Simplificación modelo

# Aplicamos para la simplificación, la función refVAR().
m2=refVAR(m1,thres = 1.96)

# D. Revisión del modelo

# Separamos nuevamente los residuales del modelo refinado y aplicamos función de revisión mediante función mq()
resi2=m2$residuals
mq(resi2, adj=12)
# Se daña el modelo????


#Podemos visualizar nuevamente los residuales, donde vemos nuevamente la mejoría respecto al modelo completo.
acf(resi2)

# Aplicamos la función de diagnóstico al modelo terminal, esto, para permitir observar si existe una dependencia inmediata en las series.
MTSdiag(m2, adj=12) #Recordar que el modelo se reduce a 12 parámetros.
# -----------------------------------------------------------
# Sección 6. Análisis Impulso - Respuesta
# -----------------------------------------------------------

# Establecer la ruta y el nombre del archivo
archivo <- "C:/Users/windows/Documents/GitHub/Problem_Set_1/Proyecto-de-grado-IIND/Proyecto de grado IIND/4. Gráficos/irf_plot.png"

# Abrir el dispositivo PNG para grabar el gráfico
png(filename = archivo)

# La función de impulso respuesta se lleva a cabo mediante la librería de vars. La función es la irf(). Apliquemos la función al primer modelo.
m1irf = irf(m0, n.ahead = 12, boot = TRUE)
plot(m1irf) 
# Se estabiliza a la media

# Cerrar el dispositivo de gráficos
dev.off()







ggsave("37. Impulso - Respuesta VAR.png", 
       plot = last_plot(), 
       path = "C:/Users/windows/Documents/GitHub/Problem_Set_1/Proyecto-de-grado-IIND/Proyecto de grado IIND/4. Gráficos", 
       width = 10, height = 6, units = "in", dpi = 300)

  
# -----------------------------------------------------------
# Sección 7: Predicción
# -----------------------------------------------------------

#Apliquemos la predicción al segundo modelo. Esto, ya que la función VARpredict pertenece a la librería de MTS.
#Igualmente, podemos observar que se generan los resultados de pronóstico de cada una de las series y las ecuaciones de estimación de las series.
predm2=VARpred(m2, 6)  #Podemos generar un pronóstico a 6 trimestres adelante.
print(head(da.ts))
var_est3 <- VAR(y=z, lag.max = 2)
summary(var_est3)

# -----------------------------------------------------------
# Sección 8: Recuperación del nivel en el pronóstico
# -----------------------------------------------------------

#Especificamos el horizonte de pronóstico.
nhor=6 #pasos en el pronóstico.
nr_lev <- nrow(da)
mr_lev= as.matrix(da)
tail(mr_lev)
str(mr_lev)

# Generamos primeramente una estructura de datos con NAs que se poblarán con los valores de pronóstico, que se irán sumando acumuladamente.
m.varf_lev_ft <- rbind(mr_lev[,3:5], matrix(NA, nhor,3 ))
head(m.varf_lev_ft)
tail(m.varf_lev_ft)
