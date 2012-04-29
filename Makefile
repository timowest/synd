
build:
	dmd -lib src/synd/*.d src/synd/effects/*.d

test:
	dmd -unittest src/synd/*.d src/synd/effects/*.d src/runtests.d -ofruntests
	./runtests

clean:
	rm *.a *.o runtests
