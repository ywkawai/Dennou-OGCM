SUBDIRS =

AM_FCFLAGS = \
        $(MODPATHFLAG)$(srcdir)/../../../include \
        $(MODPATHFLAG)$(srcdir)/../setup \
	$(FCFLAGS) $(SYSFFLAGS)

LDADD = \
	$(SYSLDFLAGS) $(SYSLDLIBS)

CLEANFILES = *$(MODEXT)

bin_PROGRAMS = 


noinst_LTLIBRARIES= 


##########


noinst_LTLIBRARIES += libSpmlUtil.la

dist_libSpmlUtil_la_SOURCES= \
	at_module_omp.f90 \
	SpmlUtil_mod2.f90

##########

noinst_LTLIBRARIES += libDSOGCMUtil.la 
dist_libDSOGCMUtil_la_SOURCES= \
	UnitConversion_mod.f90 \
	EOS_Linear_mod.f90 \
	EOS_SimpleNonLinear_mod.f90 \
	SeaWaterProp_FM83_mod.f90 \
	EOS_JM95_mod.f90 \
	EOSDriver_mod.f90 \
	DiagnoseUtil_mod.f90 \
	TemporalIntegUtil_mod.f90 \
	TemporalIntegUtil_mod2.f90



# Dependency

DiagnoseUtil_mod.f90: \
	../setup/GridSet_mod.o


EOSDriver_mod.f90: \
	../setup/Constants_mod.o \
	../setup/GridSet_mod.o \
	./EOS_Linear_mod.o \
	./EOS_SimpleNonLinear_mod.o \
	./EOS_JM95_mod.o




